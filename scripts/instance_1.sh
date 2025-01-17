#!/bin/bash
# Actualizar e instalar herramientas necesarias
yum update -y
yum install -y python3 aws-cli python3-pip
pip3 install requests

# Variables de configuración
CODE_BUCKET="graph-code-bucket-ulpgc4"
DATALAKE_BUCKET="datalake-graph-ulpgc4"
DATALAKE_DIR="/datalake"
LAST_SYNC_FILE="/tmp/last_sync_time"

# Crear directorio local
mkdir -p $DATALAKE_DIR

# Descargar y ejecutar el archivo de Python desde el bucket S3 en segundo plano
aws s3 cp s3://$CODE_BUCKET/crawler.py /tmp/crawler.py
python3 /tmp/crawler.py &  # Ejecutar el crawler en segundo plano
if [ $? -ne 0 ]; then
    echo "Error ejecutando crawler.py en segundo plano"
fi

# Inicializar archivo de marca de tiempo
if [ ! -f $LAST_SYNC_FILE ]; then
    date +%s > $LAST_SYNC_FILE
fi

# Función para sincronizar cambios locales al bucket del datalake
sync_to_datalake() {
    echo "Sincronizando cambios locales con el bucket $DATALAKE_BUCKET..."
    aws s3 cp $DATALAKE_DIR/ s3://$DATALAKE_BUCKET/ --recursive
    echo "Sincronización completada."
}

# Monitoreo periódico del datalake local
while true; do
    LAST_SYNC=$(cat $LAST_SYNC_FILE)
    echo "Revisando cambios desde: $(date -d @$LAST_SYNC)"

    CHANGES=$(find $DATALAKE_DIR -type f -newermt "@$LAST_SYNC")
    if [ ! -z "$CHANGES" ]; then
        echo "Se detectaron los siguientes cambios:"
        echo "$CHANGES"
        sync_to_datalake
        date +%s > $LAST_SYNC_FILE
    else
        echo "No se detectaron cambios."
    fi

    sleep 10
done
