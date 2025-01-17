#!/bin/bash
# Actualizar e instalar herramientas necesarias
yum update -y
yum install -y python3 aws-cli python3-pip
pip3 install boto3 jq

# Variables de configuración
CODE_BUCKET="{{ code_bucket }}"
DATALAKE_BUCKET="{{ datalake_graph_bucket }}"
DATAMART_BUCKET="{{ datamart_dictionary_bucket }}"
CURRENT_DATE=$(date +%Y%m%d)

# Obtener ACCOUNT_ID dinámicamente
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ $? -ne 0 ]; then
    echo "Error obteniendo ACCOUNT_ID. Asegúrate de que AWS CLI esté configurado correctamente."
    exit 1
fi

QUEUE_URL="https://sqs.us-east-1.amazonaws.com/$ACCOUNT_ID/$DATALAKE_BUCKET-$CURRENT_DATE-queue"
LOCAL_DATALAKE_DIR="/datalake/$CURRENT_DATE"
LOCAL_DATAMART_DIR="/datamart_dictionary"

# Crear directorios locales
mkdir -p $LOCAL_DATALAKE_DIR
mkdir -p $LOCAL_DATAMART_DIR

# Descargar el script desde el bucket de código
aws s3 cp s3://$CODE_BUCKET/dictionary-builder.py /tmp/dictionary-builder.py

# Función para sincronizar el datalake local
sync_from_datalake() {
    echo "Sincronizando datos desde la carpeta $CURRENT_DATE del bucket $DATALAKE_BUCKET..."
    aws s3 cp s3://$DATALAKE_BUCKET/$CURRENT_DATE/ $LOCAL_DATALAKE_DIR/ --recursive
    echo "Sincronización completada."
}

# Procesar mensajes de SQS
process_sqs_messages() {
    while true; do
        echo "Recibiendo mensajes de la cola SQS de la carpeta $CURRENT_DATE..."
        RESPONSE=$(aws sqs receive-message --queue-url $QUEUE_URL --max-number-of-messages 1 --region us-east-1 --query "Messages[0]" --output json)

        if [ "$RESPONSE" == "null" ]; then
            echo "No hay mensajes en la cola. Esperando..."
            sleep 10
            continue
        fi

        # Extraer el cuerpo del mensaje y el ReceiptHandle
        MESSAGE_BODY=$(echo $RESPONSE | jq -r '.Body')
        RECEIPT_HANDLE=$(echo $RESPONSE | jq -r '.ReceiptHandle')

        echo "Mensaje recibido: $MESSAGE_BODY"

        # Procesar el mensaje
        echo "Sincronizando datos del datalake..."
        sync_from_datalake

        echo "Ejecutando el script dictionary-builder.py..."
        python3 /tmp/dictionary-builder.py

        echo "Subiendo datos al bucket datamart..."
        aws s3 cp $LOCAL_DATAMART_DIR/ s3://$DATAMART_BUCKET/ --recursive

        # Eliminar el mensaje de la cola
        echo "Eliminando el mensaje de la cola SQS..."
        aws sqs delete-message --queue-url $QUEUE_URL --receipt-handle "$RECEIPT_HANDLE"

        echo "Mensaje procesado y eliminado."
    done
}

# Ejecutar la función para procesar mensajes de SQS
process_sqs_messages
