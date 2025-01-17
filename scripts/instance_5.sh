#!/bin/bash
# Actualizar e instalar herramientas necesarias
yum update -y
yum install -y python3 aws-cli python3-pip jq
pip3 install boto3

# Variables de configuración
CODE_BUCKET="graph-code-bucket-ulpgc3"
DATALAKE_BUCKET="datalake-graph-ulpgc3"
DATAMART_STATS_BUCKET="datamart-stats-ulpgc3"
LOCAL_DATALAKE_EVENTS_DIR="/datalake/events"
LOCAL_DATAMART_STATS_DIR="/datamart_stats"

# Obtener ACCOUNT_ID dinámicamente
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ $? -ne 0 ]; then
    echo "Error obteniendo ACCOUNT_ID. Asegúrate de que AWS CLI esté configurado correctamente."
    exit 1
fi

SQS_EVENTS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/$ACCOUNT_ID/datalake-graph-ulpgc3-events-queue"

# Crear directorios locales
mkdir -p $LOCAL_DATALAKE_EVENTS_DIR
mkdir -p $LOCAL_DATAMART_STATS_DIR

# Descargar el script desde el bucket de código
aws s3 cp s3://$CODE_BUCKET/stat-builder.py /tmp/stat-builder.py
if [ $? -ne 0 ]; then
    echo "Error descargando stat-builder.py desde $CODE_BUCKET."
    exit 1
fi

# Función para actualizar los eventos locales desde el bucket
update_local_events() {
    echo "Actualizando eventos locales desde el bucket $DATALAKE_BUCKET..."
    aws s3 cp s3://$DATALAKE_BUCKET/events/ $LOCAL_DATALAKE_EVENTS_DIR/ --recursive
    if [ $? -ne 0 ]; then
        echo "Error actualizando eventos locales desde $DATALAKE_BUCKET."
    else
        echo "Actualización de eventos completada."
    fi
}

# Función para procesar mensajes de SQS y ejecutar el script
process_sqs_messages() {
    while true; do
        echo "Revisando mensajes en la cola SQS para 'events'..."
        MESSAGE=$(aws sqs receive-message --queue-url $SQS_EVENTS_QUEUE_URL --max-number-of-messages 1 --wait-time-seconds 10 --region us-east-1 --query "Messages[0]")

        if [ "$MESSAGE" != "null" ]; then
            echo "Mensaje detectado en la cola SQS de 'events'."

            # Extraer ReceiptHandle del mensaje
            RECEIPT_HANDLE=$(echo $MESSAGE | jq -r '.ReceiptHandle')

            # Procesar el mensaje
            echo "Procesando evento de 'events'..."
            update_local_events

            echo "Ejecutando el script stat-builder.py..."
            python3 /tmp/stat-builder.py
            if [ $? -ne 0 ]; then
                echo "Error ejecutando el script stat-builder.py."
                continue
            fi

            echo "Subiendo resultados al bucket $DATAMART_STATS_BUCKET..."
            aws s3 cp $LOCAL_DATAMART_STATS_DIR/ s3://$DATAMART_STATS_BUCKET/ --recursive
            if [ $? -ne 0 ]; then
                echo "Error subiendo resultados a $DATAMART_STATS_BUCKET."
            fi

            # Eliminar el mensaje después de procesarlo
            echo "Eliminando mensaje de la cola..."
            aws sqs delete-message --queue-url $SQS_EVENTS_QUEUE_URL --receipt-handle "$RECEIPT_HANDLE" --region us-east-1
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
