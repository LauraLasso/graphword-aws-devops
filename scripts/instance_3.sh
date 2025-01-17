#!/bin/bash
# Actualizar e instalar herramientas necesarias
yum update -y
yum install -y python3 aws-cli python3-pip jq
pip3 install boto3

# Variables de configuración
CODE_BUCKET="graph-code-bucket-ulpgc4"
DATAMART_DICTIONARY_BUCKET="datamart-dictionary-ulpgc4"
DATAMART_GRAPH_BUCKET="datamart-graph-ulpgc4"
LOCAL_DATAMART_DICTIONARY_DIR="/datamart_dictionary"
LOCAL_DATAMART_GRAPH_DIR="/datamart_graph"

# Obtener ACCOUNT_ID dinámicamente
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ $? -ne 0 ]; then
    echo "Error obteniendo ACCOUNT_ID. Asegúrate de que AWS CLI esté configurado correctamente."
    exit 1
fi

SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/$ACCOUNT_ID/datamart-dictionary-ulpgc4-queue"

# Crear directorios locales
mkdir -p $LOCAL_DATAMART_DICTIONARY_DIR
mkdir -p $LOCAL_DATAMART_GRAPH_DIR

# Descargar el script desde el bucket de código
aws s3 cp s3://$CODE_BUCKET/graph-builder.py /tmp/graph-builder.py
if [ $? -ne 0 ]; then
    echo "Error descargando graph-builder.py desde $CODE_BUCKET."
    exit 1
fi

# Función para sincronizar datos locales desde el bucket datamart-dictionary
sync_from_dictionary() {
    echo "Sincronizando datos desde el bucket $DATAMART_DICTIONARY_BUCKET..."
    aws s3 cp s3://$DATAMART_DICTIONARY_BUCKET/ $LOCAL_DATAMART_DICTIONARY_DIR/ --recursive
    if [ $? -ne 0 ]; then
        echo "Error sincronizando datos desde $DATAMART_DICTIONARY_BUCKET."
    else
        echo "Sincronización completada."
    fi
}

# Monitorear mensajes en la cola SQS y ejecutar el script
while true; do
    echo "Revisando mensajes en la cola SQS..."
    MESSAGE=$(aws sqs receive-message --queue-url $SQS_QUEUE_URL --max-number-of-messages 1 --wait-time-seconds 10 --region us-east-1 --query "Messages[0]" --output json)

    if [ "$MESSAGE" != "null" ]; then
        echo "Mensaje detectado en la cola SQS."

        # Extraer ReceiptHandle del mensaje
        RECEIPT_HANDLE=$(echo $MESSAGE | jq -r '.ReceiptHandle')

        # Procesar el mensaje
        echo "Procesando evento..."
        sync_from_dictionary
        python3 /tmp/graph-builder.py
        if [ $? -ne 0 ]; then
            echo "Error ejecutando graph-builder.py."
        fi

        echo "Subiendo datos procesados al bucket $DATAMART_GRAPH_BUCKET..."
        aws s3 cp $LOCAL_DATAMART_GRAPH_DIR/ s3://$DATAMART_GRAPH_BUCKET/ --recursive
        if [ $? -ne 0 ]; then
            echo "Error subiendo datos al bucket $DATAMART_GRAPH_BUCKET."
        fi

        # Eliminar el mensaje después de procesarlo
        echo "Eliminando mensaje de la cola..."
        aws sqs purge-queue --queue-url $SQS_QUEUE_URL --region us-east-1
        # aws sqs delete-message --queue-url $SQS_QUEUE_URL --receipt-handle "$RECEIPT_HANDLE" --region us-east-1
        if [ $? -ne 0 ]; then
            echo "Error eliminando mensaje de la cola SQS."
        fi
    else
        echo "No hay mensajes en la cola. Esperando..."
    fi

    sleep 5
done