#!/bin/bash

echo "Iniciando eliminación de recursos AWS relacionados con GraphWord..."

# Variables con los nombres reales
DATALAKE_GRAPH_BUCKET="datalake-graph-ulpgc0"
DATAMART_DICTIONARY_BUCKET="datamart-dictionary-ulpgc0"
DATAMART_GRAPH_BUCKET="datamart-graph-ulpgc0"
DATAMART_STATS_BUCKET="datamart-stats-ulpgc0"
CODE_BUCKET="graph-code-bucket-ulpgc0"
CURRENT_DATE=$(date +%Y%m%d)  # Fecha dinámica


# Nombres completos de las colas SQS
QUEUE_KEYS=(
  "${DATALAKE_GRAPH_BUCKET}-events-queue"
  "${DATALAKE_GRAPH_BUCKET}-${CURRENT_DATE}-queue"
  "${DATAMART_DICTIONARY_BUCKET}-queue"
  "${DATAMART_GRAPH_BUCKET}-queue"
  "${DATAMART_STATS_BUCKET}-queue"
)

# Seguridad y balanceadores
SECURITY_GROUPS=("ALB_SG" "API_SSH_Group")
LOAD_BALANCER_NAME="api-load-balancer"
TARGET_GROUP_NAME="api-target-group"

# 1. Eliminar colas SQS
echo "Eliminando colas SQS..."
for queue_name in "${QUEUE_KEYS[@]}"; do
  queue_url=$(aws sqs get-queue-url --queue-name "$queue_name" --query "QueueUrl" --output text 2>/dev/null)
  if [ -n "$queue_url" ]; then
    echo "Vaciando mensajes de la cola: $queue_url"
    aws sqs purge-queue --queue-url "$queue_url"
    echo "Eliminando la cola SQS: $queue_url"
    aws sqs delete-queue --queue-url "$queue_url"
  else
    echo "La cola SQS $queue_name no existe o ya fue eliminada."
  fi
done

# 2. Eliminar los buckets S3
buckets=("$DATALAKE_GRAPH_BUCKET" "$DATAMART_DICTIONARY_BUCKET" "$DATAMART_GRAPH_BUCKET" "$DATAMART_STATS_BUCKET" "$CODE_BUCKET")

for bucket in "${buckets[@]}"; do
  echo "Eliminando el bucket S3: $bucket"
  aws s3 rb "s3://$bucket" --force
done

# 5. Eliminar Load Balancer y Target Group
echo "Eliminando el Load Balancer y Target Group..."
load_balancer_arn=$(aws elbv2 describe-load-balancers --names "$LOAD_BALANCER_NAME" --query "LoadBalancers[0].LoadBalancerArn" --output text)
if [ "$load_balancer_arn" != "None" ]; then
  aws elbv2 delete-load-balancer --load-balancer-arn "$load_balancer_arn"
  echo "Esperando a que el Load Balancer se elimine..."
  aws elbv2 wait load-balancer-deleted --load-balancer-arns "$load_balancer_arn"
else
  echo "No se encontró el Load Balancer."
fi

target_group_arn=$(aws elbv2 describe-target-groups --names "$TARGET_GROUP_NAME" --query "TargetGroups[0].TargetGroupArn" --output text)
if [ "$target_group_arn" != "None" ]; then
  aws elbv2 delete-target-group --target-group-arn "$target_group_arn"
  echo "Target Group eliminado."
else
  echo "No se encontró el Target Group."
fi

# 3. Eliminar instancias EC2
echo "Eliminando instancias EC2..."
instance_ids=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=EC2Instance-*" --query "Reservations[].Instances[].InstanceId" --output text)
if [ -n "$instance_ids" ]; then
  aws ec2 terminate-instances --instance-ids $instance_ids
  echo "Esperando a que las instancias EC2 se eliminen..."
  aws ec2 wait instance-terminated --instance-ids $instance_ids
else
  echo "No se encontraron instancias EC2 relacionadas."
fi

# 4. Eliminar grupos de seguridad
for sg_name in "${SECURITY_GROUPS[@]}"; do
  sg_id=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$sg_name" --query "SecurityGroups[0].GroupId" --output text)
  if [ "$sg_id" != "None" ]; then
    echo "Eliminando el grupo de seguridad: $sg_name ($sg_id)..."
    aws ec2 delete-security-group --group-id "$sg_id"
  else
    echo "No se encontró el grupo de seguridad $sg_name."
  fi
done



echo "Proceso de eliminación completado."
