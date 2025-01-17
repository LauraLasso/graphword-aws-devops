#!/bin/bash
yum update -y
yum install -y python3 aws-cli python3-pip
pip3 install boto3 jq

CODE_BUCKET="{{ code_bucket }}"
DATALAKE_BUCKET="{{ datalake_graph_bucket }}"
DATAMART_BUCKET="{{ datamart_dictionary_bucket }}"
CURRENT_DATE=$(date +%Y%m%d)

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ $? -ne 0 ]; then
    echo "Error retrieving ACCOUNT_ID. Ensure AWS CLI is correctly configured."
    exit 1
fi

QUEUE_URL="https://sqs.us-east-1.amazonaws.com/$ACCOUNT_ID/$DATALAKE_BUCKET-$CURRENT_DATE-queue"
LOCAL_DATALAKE_DIR="/datalake/$CURRENT_DATE"
LOCAL_DATAMART_DIR="/datamart_dictionary"

mkdir -p $LOCAL_DATALAKE_DIR
mkdir -p $LOCAL_DATAMART_DIR

aws s3 cp s3://$CODE_BUCKET/dictionary-builder.py /tmp/dictionary-builder.py

sync_from_datalake() {
    echo "Syncing data from folder $CURRENT_DATE in bucket $DATALAKE_BUCKET..."
    aws s3 cp s3://$DATALAKE_BUCKET/$CURRENT_DATE/ $LOCAL_DATALAKE_DIR/ --recursive
    echo "Sync completed."
}

process_sqs_messages() {
    while true; do
        echo "Receiving messages from the SQS queue for folder $CURRENT_DATE..."
        RESPONSE=$(aws sqs receive-message --queue-url $QUEUE_URL --max-number-of-messages 1 --region us-east-1 --query "Messages[0]" --output json)

        if [ "$RESPONSE" == "null" ]; then
            echo "No messages in the queue. Waiting..."
            sleep 10
            continue
        fi

        MESSAGE_BODY=$(echo $RESPONSE | jq -r '.Body')
        RECEIPT_HANDLE=$(echo $RESPONSE | jq -r '.ReceiptHandle')

        echo "Message received: $MESSAGE_BODY"

        echo "Syncing data from the datalake..."
        sync_from_datalake

        echo "Executing the script dictionary-builder.py..."
        python3 /tmp/dictionary-builder.py

        echo "Uploading data to the datamart bucket..."
        aws s3 cp $LOCAL_DATAMART_DIR/ s3://$DATAMART_BUCKET/ --recursive

        echo "Deleting the message from the SQS queue..."
        aws sqs delete-message --queue-url $QUEUE_URL --receipt-handle "$RECEIPT_HANDLE"

        echo "Message processed and deleted."
    done
}

process_sqs_messages
