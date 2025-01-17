#!/bin/bash
yum update -y
yum install -y python3 aws-cli python3-pip
pip3 install requests

CODE_BUCKET="{{ code_bucket }}"
DATALAKE_BUCKET="{{ datalake_graph_bucket }}"
DATALAKE_DIR="/datalake"
LAST_SYNC_FILE="/tmp/last_sync_time"

mkdir -p $DATALAKE_DIR

aws s3 cp s3://$CODE_BUCKET/crawler.py /tmp/crawler.py
python3 /tmp/crawler.py &  
if [ $? -ne 0 ]; then
    echo "Error running crawler.py in the background"
fi

if [ ! -f $LAST_SYNC_FILE ]; then
    date +%s > $LAST_SYNC_FILE
fi

sync_to_datalake() {
    echo "Syncing local changes to the bucket $DATALAKE_BUCKET..."
    aws s3 cp $DATALAKE_DIR/ s3://$DATALAKE_BUCKET/ --recursive
    echo "Sync completed."
}

while true; do
    LAST_SYNC=$(cat $LAST_SYNC_FILE)
    echo "Checking for changes since: $(date -d @$LAST_SYNC)"

    CHANGES=$(find $DATALAKE_DIR -type f -newermt "@$LAST_SYNC")
    if [ ! -z "$CHANGES" ]; then
        echo "The following changes were detected:"
        echo "$CHANGES"
        sync_to_datalake
        date +%s > $LAST_SYNC_FILE
    else
        echo "No changes detected."
    fi

    sleep 10
done
