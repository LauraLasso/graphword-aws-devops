#!/bin/bash
yum update -y
yum install -y python3 aws-cli python3-pip jq
pip3 install boto3

CODE_BUCKET="{{ code_bucket }}"
DATAMART_DICTIONARY_BUCKET="{{ datamart_dictionary_bucket }}"
DATAMART_GRAPH_BUCKET="{{ datamart_graph_bucket }}"
LOCAL_DATAMART_DICTIONARY_DIR="/datamart_dictionary"
LOCAL_DATAMART_GRAPH_DIR="/datamart_graph"

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ $? -ne 0 ]; then
    echo "Error retrieving ACCOUNT_ID. Ensure AWS CLI is correctly configured."
    exit 1
fi

SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/$ACCOUNT_ID/$DATAMART_DICTIONARY_BUCKET-queue"

mkdir -p $LOCAL_DATAMART_DICTIONARY_DIR
mkdir -p $LOCAL_DATAMART_GRAPH_DIR

aws s3 cp s3://$CODE_BUCKET/graph-builder.py /tmp/graph-builder.py
if [ $? -ne 0 ]; then
    echo "Error downloading graph-builder.py from $CODE_BUCKET."
    exit 1
fi

sync_from_dictionary() {
    echo "Syncing data from the bucket $DATAMART_DICTIONARY_BUCKET..."
    aws s3 cp s3://$DATAMART_DICTIONARY_BUCKET/ $LOCAL_DATAMART_DICTIONARY_DIR/ --recursive
    if [ $? -ne 0 ]; then
        echo "Error syncing data from $DATAMART_DICTIONARY_BUCKET."
    else
        echo "Sync completed."
    fi
}

while true; do
    echo "Checking messages in the SQS queue..."
    MESSAGE=$(aws sqs receive-message --queue-url $SQS_QUEUE_URL --max-number-of-messages 1 --wait-time-seconds 10 --region us-east-1 --query "Messages[0]" --output json)

    if [ "$MESSAGE" != "null" ]; then
        echo "Message detected in the SQS queue."

        RECEIPT_HANDLE=$(echo $MESSAGE | jq -r '.ReceiptHandle')

        echo "Processing event..."
        sync_from_dictionary
        python3 /tmp/graph-builder.py
        if [ $? -ne 0 ]; then
            echo "Error executing graph-builder.py."
        fi

        echo "Uploading processed data to the bucket $DATAMART_GRAPH_BUCKET..."
        aws s3 cp $LOCAL_DATAMART_GRAPH_DIR/ s3://$DATAMART_GRAPH_BUCKET/ --recursive
        if [ $? -ne 0 ]; then
            echo "Error uploading data to $DATAMART_GRAPH_BUCKET."
        fi

        echo "Deleting message from the SQS queue..."
        aws sqs purge-queue --queue-url $SQS_QUEUE_URL --region us-east-1
        if [ $? -ne 0 ]; then
            echo "Error deleting message from the SQS queue."
        fi
    else
        echo "No messages in the queue. Waiting..."
    fi

    sleep 5
done