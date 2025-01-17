#!/bin/bash
# Actualizar e instalar herramientas necesarias
yum update -y
yum install -y python3 aws-cli python3-pip jq
pip3 install boto3 flask

# Variables de configuración
CODE_BUCKET="graph-code-bucket-ulpgc4"
DATAMART_STATS_BUCKET="datamart-stats-ulpgc4"
LOCAL_DATAMART_STATS_DIR="/datamart_stats"
SCRIPT_PATH="/tmp/stat-query.py"

# Obtener ACCOUNT_ID dinámicamente
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)ye
if [ $? -ne 0 ]; then
    echo "Error obteniendo ACCOUNT_ID. Asegúrate de que AWS CLI esté configurado correctamente."
    exit 1
fi

SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/$ACCOUNT_ID/datamart-stats-ulpgc4-queue"

# Crear directorio local para datamart_stats
mkdir -p $LOCAL_DATAMART_STATS_DIR

# Descargar el script desde el bucket de código
aws s3 cp s3://$CODE_BUCKET/stat-query.py $SCRIPT_PATH
if [ $? -ne 0 ]; then
    echo "Error descargando stat-query.py desde $CODE_BUCKET."
    exit 1
fi

# Ejecutar el servicio Flask para la API en segundo plano
python3 $SCRIPT_PATH &
if [ $? -ne 0 ]; then
    echo "Error iniciando el servicio Flask."
    exit 1
fi

# Función para sincronizar cambios del bucket al datamart local
sync_from_bucket() {
    echo "Sincronizando datos locales desde el bucket $DATAMART_STATS_BUCKET..."
    aws s3 cp s3://$DATAMART_STATS_BUCKET/ $LOCAL_DATAMART_STATS_DIR/ --recursive
    if [ $? -ne 0 ]; then
        echo "Error sincronizando datos desde $DATAMART_STATS_BUCKET."
    else
        echo "Sincronización completada."
    fi
}

# Función para procesar mensajes de SQS y manejar cambios
process_sqs_messages() {
    while true; do
        echo "Revisando mensajes en la cola SQS..."
        MESSAGE=$(aws sqs receive-message --queue-url $SQS_QUEUE_URL --max-number-of-messages 1 --wait-time-seconds 10 --region us-east-1 --query "Messages[0]")

        if [ "$MESSAGE" != "null" ]; then
            echo "Mensaje detectado en la cola SQS."

            # Extraer ReceiptHandle del mensaje
            RECEIPT_HANDLE=$(echo $MESSAGE | jq -r '.ReceiptHandle')

            # Manejar el mensaje
            echo "Procesando evento para $DATAMART_STATS_BUCKET..."
            sync_from_bucket

            echo "Reiniciando el servicio Flask..."
            pkill -f stat-query.py
            python3 $SCRIPT_PATH &
            if [ $? -ne 0 ]; then
                echo "Error reiniciando el servicio Flask."
            fi

            # Eliminar el mensaje después de procesarlo
            echo "Eliminando mensaje de la cola..."
            aws sqs delete-message --queue-url $SQS_QUEUE_URL --receipt-handle "$RECEIPT_HANDLE" --region us-east-1
            if [ $? -ne 0 ]; then
                echo "Error eliminando mensaje de la cola SQS."
            fi
        else
            echo "No hay mensajes en la cola. Esperando..."
        fi

        sleep 5
    done
}

# Ejecutar el monitoreo de SQS
process_sqs_messages
