#!/bin/bash
yum update -y
yum install -y python3 aws-cli python3-pip jq
pip3 install networkx matplotlib flask boto3

CODE_BUCKET="{{ code_bucket }}"
DATAMART_GRAPH_BUCKET="{{ datamart_graph_bucket }}"
DATALAKE_BUCKET="{{ datalake_graph_bucket }}"
LOCAL_DATAMART_GRAPH_DIR="/datamart_graph"
LOCAL_EVENTS_DIR="/datalake/events"
LAST_SYNC_FILE="/tmp/last_sync_time"
SCRIPT_PATH="/tmp/graph-query.py"


ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ $? -ne 0 ]; then
    echo "Error retrieving ACCOUNT_ID. Ensure AWS CLI is correctly configured."
    exit 1
fi

SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/$ACCOUNT_ID/$DATAMART_GRAPH_BUCKET-queue"

mkdir -p $LOCAL_DATAMART_GRAPH_DIR
mkdir -p $LOCAL_EVENTS_DIR

aws s3 cp s3://$CODE_BUCKET/graph-query.py $SCRIPT_PATH
if [ $? -ne 0 ]; then
    echo "Error downloading graph-query.py from $CODE_BUCKET."
    exit 1
fi

aws s3 cp s3://$DATAMART_GRAPH_BUCKET/ $LOCAL_DATAMART_GRAPH_DIR/ --recursive
if [ $? -ne 0 ]; then
    echo "Error downloading data from $DATAMART_GRAPH_BUCKET."
    exit 1
fi

python3 $SCRIPT_PATH &
if [ $? -ne 0 ]; then
    echo "Error starting the Flask API with $SCRIPT_PATH."
    exit 1
fi

if [ ! -f $LAST_SYNC_FILE ]; then
    date +%s > $LAST_SYNC_FILE
fi

sync_events_to_datalake() {
    echo "Syncing local events with bucket $DATALAKE_BUCKET..."
    aws s3 cp $LOCAL_EVENTS_DIR/ s3://$DATALAKE_BUCKET/events/ --recursive
    if [ $? -ne 0 ]; then
        echo "Error syncing events with $DATALAKE_BUCKET."
    else
        echo "Event synchronization completed."
    fi
}

sync_from_datamart_graph() {
    echo "Syncing data from bucket $DATAMART_GRAPH_BUCKET..."
    aws s3 cp s3://$DATAMART_GRAPH_BUCKET/ $LOCAL_DATAMART_GRAPH_DIR/ --recursive
    if [ $? -ne 0 ]; then
        echo "Error syncing data from $DATAMART_GRAPH_BUCKET."
    else
        echo "Synchronization completed for datamart-graph."
    fi
}

monitor_local_events() {
    while true; do
        LAST_SYNC=$(cat $LAST_SYNC_FILE)
        echo "Checking for changes in 'events' since: $(date -d @$LAST_SYNC)"

        CHANGES=$(find $LOCAL_EVENTS_DIR -type f -newermt "@$LAST_SYNC")
        if [ ! -z "$CHANGES" ]; then
            echo "The following changes were detected in 'events':"
            echo "$CHANGES"

            sync_events_to_datalake

            date +%s > $LAST_SYNC_FILE
        else
            echo "No changes detected in 'events'."
        fi

        sleep 10
    done
}

monitor_sqs_datamart_graph() {
    while true; do
        echo "Checking for messages in the SQS queue..."
        MESSAGE=$(aws sqs receive-message --queue-url $SQS_QUEUE_URL --max-number-of-messages 1 --wait-time-seconds 10 --region us-east-1 --query "Messages[0]" --output json)

        if [ "$MESSAGE" != "null" ]; then
            echo "Message detected in the SQS queue."

            echo "Processing event..."
            sync_from_datamart_graph
            pkill -f graph-query.py
            python3 $SCRIPT_PATH &
            if [ $? -ne 0 ]; then
                echo "Error restarting the Flask API with $SCRIPT_PATH."
            fi

        else
            echo "No messages in the queue. Waiting..."
        fi

        sleep 5
    done
}

monitor_local_events &
monitor_sqs_datamart_graph &
wait
