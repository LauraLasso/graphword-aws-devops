#!/bin/bash
yum update -y
yum install -y python3 aws-cli python3-pip jq
pip3 install boto3

CODE_BUCKET="{{ code_bucket }}"
DATALAKE_BUCKET="{{ datalake_graph_bucket }}"
DATAMART_STATS_BUCKET="{{ datamart_stats_bucket }}"
LOCAL_DATALAKE_EVENTS_DIR="/datalake/events"
LOCAL_DATAMART_STATS_DIR="/datamart_stats"

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ $? -ne 0 ]; then
    echo "Error retrieving ACCOUNT_ID. Ensure AWS CLI is correctly configured."
    exit 1
fi

SQS_EVENTS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/$ACCOUNT_ID/$DATALAKE_BUCKET-events-queue"

mkdir -p $LOCAL_DATALAKE_EVENTS_DIR
mkdir -p $LOCAL_DATAMART_STATS_DIR

aws s3 cp s3://$CODE_BUCKET/stat-builder.py /tmp/stat-builder.py
if [ $? -ne 0 ]; then
    echo "Error downloading stat-builder.py from $CODE_BUCKET."
    exit 1
fi

update_local_events() {
    echo "Updating local events from bucket $DATALAKE_BUCKET..."
    aws s3 cp s3://$DATALAKE_BUCKET/events/ $LOCAL_DATALAKE_EVENTS_DIR/ --recursive
    if [ $? -ne 0 ]; then
        echo "Error updating local events from $DATALAKE_BUCKET."
    else
        echo "Event update completed."
    fi
}

process_sqs_messages() {
    while true; do
        echo "Checking messages in the SQS queue for 'events'..."
        MESSAGE=$(aws sqs receive-message --queue-url $SQS_EVENTS_QUEUE_URL --max-number-of-messages 1 --wait-time-seconds 10 --region us-east-1 --query "Messages[0]")

        if [ "$MESSAGE" != "null" ]; then
            echo "Message detected in the SQS queue for 'events'."

            RECEIPT_HANDLE=$(echo $MESSAGE | jq -r '.ReceiptHandle')

            echo "Processing event from 'events'..."
            update_local_events

            echo "Running the stat-builder.py script..."
            python3 /tmp/stat-builder.py
            if [ $? -ne 0 ]; then
                echo "Error running the stat-builder.py script."
                continue
            fi

            echo "Uploading results to bucket $DATAMART_STATS_BUCKET..."
            aws s3 cp $LOCAL_DATAMART_STATS_DIR/ s3://$DATAMART_STATS_BUCKET/ --recursive
            if [ $? -ne 0 ]; then
                echo "Error uploading results to $DATAMART_STATS_BUCKET."
            fi

            echo "Deleting message from the SQS queue..."
            aws sqs delete-message --queue-url $SQS_EVENTS_QUEUE_URL --receipt-handle "$RECEIPT_HANDLE" --region us-east-1
            if [ $? -ne 0 ]; then
                echo "Error deleting message from the SQS queue."
            fi
        else
            echo "No messages in the queue. Waiting..."
        fi

        sleep 5
    done
}

process_sqs_messages
