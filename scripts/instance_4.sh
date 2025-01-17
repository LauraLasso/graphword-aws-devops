#!/bin/bash
# Actualizar e instalar herramientas necesarias
yum update -y
yum install -y python3 aws-cli python3-pip jq
pip3 install networkx matplotlib flask boto3

# Variables de configuración
CODE_BUCKET="graph-code-bucket-ulpgc3"
DATAMART_GRAPH_BUCKET="datamart-graph-ulpgc3"
DATALAKE_BUCKET="datalake-graph-ulpgc3"
LOCAL_DATAMART_GRAPH_DIR="/datamart_graph"
LOCAL_EVENTS_DIR="/datalake/events"
LAST_SYNC_FILE="/tmp/last_sync_time"
SCRIPT_PATH="/tmp/graph-query.py"


# Obtener ACCOUNT_ID dinámicamente
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ $? -ne 0 ]; then
    echo "Error obteniendo ACCOUNT_ID. Asegúrate de que AWS CLI esté configurado correctamente."
    exit 1
fi

SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/$ACCOUNT_ID/datamart-graph-ulpgc3-queue"

# Crear directorios locales
mkdir -p $LOCAL_DATAMART_GRAPH_DIR
mkdir -p $LOCAL_EVENTS_DIR

# Descargar el script desde el bucket de código
aws s3 cp s3://$CODE_BUCKET/graph-query.py $SCRIPT_PATH
if [ $? -ne 0 ]; then
    echo "Error descargando graph-query.py desde $CODE_BUCKET."
    exit 1
fi

# Descargar datos desde el bucket datamart-graph al directorio local
aws s3 cp s3://$DATAMART_GRAPH_BUCKET/ $LOCAL_DATAMART_GRAPH_DIR/ --recursive
if [ $? -ne 0 ]; then
    echo "Error descargando datos desde $DATAMART_GRAPH_BUCKET."
    exit 1
fi

# Ejecutar el servicio Flask para la API en segundo plano
python3 $SCRIPT_PATH &
if [ $? -ne 0 ]; then
    echo "Error iniciando la API Flask con $SCRIPT_PATH."
    exit 1
fi

# Inicializar el archivo de marca de tiempo
if [ ! -f $LAST_SYNC_FILE ]; then
    date +%s > $LAST_SYNC_FILE
fi

# Función para sincronizar la carpeta "events" local con el bucket del datalake
sync_events_to_datalake() {
    echo "Sincronizando eventos locales con el bucket $DATALAKE_BUCKET..."
    aws s3 cp $LOCAL_EVENTS_DIR/ s3://$DATALAKE_BUCKET/events/ --recursive
    if [ $? -ne 0 ]; then
        echo "Error sincronizando eventos con $DATALAKE_BUCKET."
    else
        echo "Sincronización de eventos completada."
    fi
}

# Función para sincronizar datos desde el bucket datamart-graph
sync_from_datamart_graph() {
    echo "Sincronizando datos desde el bucket $DATAMART_GRAPH_BUCKET..."
    aws s3 cp s3://$DATAMART_GRAPH_BUCKET/ $LOCAL_DATAMART_GRAPH_DIR/ --recursive
    if [ $? -ne 0 ]; then
        echo "Error sincronizando datos desde $DATAMART_GRAPH_BUCKET."
    else
        echo "Sincronización completada para datamart-graph."
    fi
}

# Monitoreo de cambios en la carpeta local "events"
monitor_local_events() {
    while true; do
        LAST_SYNC=$(cat $LAST_SYNC_FILE)
        echo "Revisando cambios en 'events' desde: $(date -d @$LAST_SYNC)"

        CHANGES=$(find $LOCAL_EVENTS_DIR -type f -newermt "@$LAST_SYNC")
        if [ ! -z "$CHANGES" ]; then
            echo "Se detectaron los siguientes cambios en 'events':"
            echo "$CHANGES"

            # Sincronizar cambios detectados
            sync_events_to_datalake

            # Actualizar la marca de tiempo
            date +%s > $LAST_SYNC_FILE
        else
            echo "No se detectaron cambios en 'events'."
        fi

        sleep 10
    done
}

# Monitorear mensajes de SQS para datamart-graph y reiniciar la API si hay cambios
monitor_sqs_datamart_graph() {
    while true; do
        echo "Revisando mensajes en la cola SQS..."
        MESSAGE=$(aws sqs receive-message --queue-url $SQS_QUEUE_URL --max-number-of-messages 1 --wait-time-seconds 10 --region us-east-1 --query "Messages[0]" --output json)

        if [ "$MESSAGE" != "null" ]; then
            echo "Mensaje detectado en la cola SQS."

            # Procesar el mensaje
            echo "Procesando evento..."
            sync_from_datamart_graph
            pkill -f graph-query.py
            python3 $SCRIPT_PATH &
            if [ $? -ne 0 ]; then
                echo "Error reiniciando la API Flask con $SCRIPT_PATH."
            fi

            # Purge de la cola SQS en vez de eliminar un solo mensaje
            echo "Vaciando toda la cola SQS..."
            aws sqs purge-queue --queue-url $SQS_QUEUE_URL --region us-east-1
            if [ $? -ne 0 ]; then
                echo "Error al vaciar la cola SQS."
            else
                echo "Cola SQS vaciada con éxito."
            fi
        else
            echo "No hay mensajes en la cola. Esperando..."
        fi

        sleep 5
    done
}

# Ejecutar monitoreo de eventos locales y SQS en paralelo
monitor_local_events &
monitor_sqs_datamart_graph &
wait
