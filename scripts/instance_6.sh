#!/bin/bash
yum update -y
yum install -y python3 aws-cli python3-pip jq
pip3 install boto3 flask

CODE_BUCKET="{{ code_bucket }}"
DATAMART_STATS_BUCKET="{{ datamart_stats_bucket }}"
LOCAL_DATAMART_STATS_DIR="/datamart_stats"
SCRIPT_PATH="/tmp/stat-query.py"

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ $? -ne 0 ]; then
    echo "Error retrieving ACCOUNT_ID. Ensure AWS CLI is correctly configured."
    exit 1
fi

SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/$ACCOUNT_ID/$DATAMART_STATS_BUCKET-queue"

mkdir -p $LOCAL_DATAMART_STATS_DIR

aws s3 cp s3://$CODE_BUCKET/stat-query.py $SCRIPT_PATH
if [ $? -ne 0 ]; then
    echo "Error downloading stat-query.py from $CODE_BUCKET."
    exit 1
fi

python3 $SCRIPT_PATH &
if [ $? -ne 0 ]; then
    echo "Error starting the Flask service."
    exit 1
fi

sync_from_bucket() {
    echo "Synchronizing local data from the bucket $DATAMART_STATS_BUCKET..."
    aws s3 cp s3://$DATAMART_STATS_BUCKET/ $LOCAL_DATAMART_STATS_DIR/ --recursive
    if [ $? -ne 0 ]; then
        echo "Error synchronizing data from $DATAMART_STATS_BUCKET."
    else
        echo "Synchronization completed."
    fi
}

process_sqs_messages() {
    while true; do
        echo "Checking messages in the SQS queue..."
        MESSAGE=$(aws sqs receive-message --queue-url $SQS_QUEUE_URL --max-number-of-messages 1 --wait-time-seconds 10 --region us-east-1 --query "Messages[0]")

        if [ "$MESSAGE" != "null" ]; then
            echo "Message detected in the SQS queue."

            RECEIPT_HANDLE=$(echo $MESSAGE | jq -r '.ReceiptHandle')

            echo "Processing event for $DATAMART_STATS_BUCKET..."
            sync_from_bucket

            echo "Restarting the Flask service..."
            pkill -f stat-query.py
            python3 $SCRIPT_PATH &
            if [ $? -ne 0 ]; then
                echo "Error restarting the Flask service."
            fi

            echo "Deleting message from the SQS queue..."
            aws sqs delete-message --queue-url $SQS_QUEUE_URL --receipt-handle "$RECEIPT_HANDLE" --region us-east-1
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
