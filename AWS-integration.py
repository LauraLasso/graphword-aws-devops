import boto3
import zipfile
import os
import json

# Inicialización de clientes de boto3
s3 = boto3.client('s3')
iam = boto3.client('iam')
lambda_client = boto3.client('lambda')

# Configuración general
REGION = 'us-east-1'
DATALAKE_BUCKET = 'project-datalake'
DATAMART_BUCKET = 'project-datamarts'
EVENTS_BUCKET = 'project-events'
LAMBDA_ROLE_NAME = 'LambdaExecutionRole'
FUNCTIONS = ['crawler', 'dictionary_builder', 'graph_builder', 'graph_query', 'stat_builder', 'stats_query']

# Crear un archivo ZIP para Lambda
def create_lambda_zip(function_name, code):
    """Crear un archivo ZIP para Lambda."""
    os.makedirs('lambda_functions', exist_ok=True)
    zip_path = f'lambda_functions/{function_name}.zip'
    with open(f'{function_name}.py', 'w') as f:
        f.write(code)
    with zipfile.ZipFile(zip_path, 'w') as zipf:
        zipf.write(f'{function_name}.py')
    os.remove(f'{function_name}.py')
    print(f"ZIP creado para {function_name}: {zip_path}")
    return zip_path


# Crear Buckets S3
def create_s3_buckets():
    """Crear buckets de S3 para datalake, datamarts y eventos."""
    buckets = [DATALAKE_BUCKET, DATAMART_BUCKET, EVENTS_BUCKET]
    for bucket in buckets:
        try:
            if REGION == 'us-east-1':
                s3.create_bucket(Bucket=bucket)
            else:
                s3.create_bucket(
                    Bucket=bucket,
                    CreateBucketConfiguration={'LocationConstraint': REGION}
                )
            print(f"Bucket {bucket} creado exitosamente.")
        except Exception as e:
            print(f"Error creando bucket {bucket}: {e}")


# Crear un rol para Lambda
def create_lambda_execution_role():
    """Crear un rol de ejecución para Lambda."""
    try:
        assume_role_policy = json.dumps({
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {"Service": "lambda.amazonaws.com"},
                    "Action": "sts:AssumeRole"
                }
            ]
        })
        role = iam.create_role(
            RoleName=LAMBDA_ROLE_NAME,
            AssumeRolePolicyDocument=assume_role_policy
        )
        iam.attach_role_policy(
            RoleName=LAMBDA_ROLE_NAME,
            PolicyArn="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
        )
        iam.attach_role_policy(
            RoleName=LAMBDA_ROLE_NAME,
            PolicyArn="arn:aws:iam::aws:policy/AmazonS3FullAccess"
        )
        print(f"Rol {LAMBDA_ROLE_NAME} creado exitosamente.")
        return role['Role']['Arn']
    except Exception as e:
        print(f"Error creando rol Lambda: {e}")
        return None


# Crear una función Lambda
def create_lambda_function(function_name, role_arn, zip_path):
    """Crear una función Lambda desde cero."""
    try:
        with open(zip_path, 'rb') as zip_file:
            code = zip_file.read()

        lambda_client.create_function(
            FunctionName=function_name,
            Runtime='python3.9',
            Role=role_arn,
            Handler=f'{function_name}.lambda_handler',
            Code={'ZipFile': code},
            Timeout=60
        )
        print(f"Función Lambda {function_name} creada exitosamente.")
    except Exception as e:
        print(f"Error creando función Lambda {function_name}: {e}")


# Configurar eventos de S3 para disparar Lambdas
def configure_s3_notifications(bucket_name, lambda_arn, suffix_filter):
    """Configurar notificaciones S3 para disparar una Lambda."""
    try:
        s3.put_bucket_notification_configuration(
            Bucket=bucket_name,
            NotificationConfiguration={
                'LambdaFunctionConfigurations': [
                    {
                        'LambdaFunctionArn': lambda_arn,
                        'Events': ['s3:ObjectCreated:*'],
                        'Filter': {
                            'Key': {
                                'FilterRules': [
                                    {'Name': 'suffix', 'Value': suffix_filter}
                                ]
                            }
                        }
                    }
                ]
            }
        )
        print(f"Notificaciones configuradas para el bucket {bucket_name}")
    except Exception as e:
        print(f"Error configurando notificaciones para {bucket_name}: {e}")


# Crear Lambdas con lógica específica
def create_all_lambdas(role_arn):
    """Crear las funciones Lambda con su lógica específica."""
    lambdas_code = {
        'crawler': """
import boto3
from datetime import datetime

s3 = boto3.client('s3')
DATALAKE_BUCKET = 'project-datalake'

def lambda_handler(event, context):
    book_content = 'Este es un libro de prueba.'
    current_date = datetime.now().strftime('%Y-%m-%d')
    key = f"{current_date}/book.txt"
    s3.put_object(Bucket=DATALAKE_BUCKET, Key=key, Body=book_content)
    return {'statusCode': 200, 'body': f"Libro guardado en {key}"}
""",
        'dictionary_builder': """
import boto3
from collections import Counter
import json

s3 = boto3.client('s3')
DATALAKE_BUCKET = 'project-datalake'
DATAMART_BUCKET = 'project-datamarts'

def lambda_handler(event, context):
    record = event['Records'][0]
    key = record['s3']['object']['key']
    response = s3.get_object(Bucket=DATALAKE_BUCKET, Key=key)
    content = response['Body'].read().decode('utf-8')
    word_count = Counter(content.split())
    output_key = f"datamart_dictionary/{key.split('/')[-1].replace('.txt', '_word_count.json')}"
    s3.put_object(Bucket=DATAMART_BUCKET, Key=output_key, Body=json.dumps(word_count))
    return {'statusCode': 200, 'body': f"Diccionario actualizado en {output_key}"}
""",
        'graph_builder': """
import boto3
import json

s3 = boto3.client('s3')
DATAMART_BUCKET = 'project-datamarts'

def lambda_handler(event, context):
    global_key = 'datamart_dictionary/global_word_count.json'
    response = s3.get_object(Bucket=DATAMART_BUCKET, Key=global_key)
    global_words = json.loads(response['Body'].read().decode('utf-8'))
    graph = {word: [w for w in global_words if len(w) == len(word)] for word in global_words}
    s3.put_object(Bucket=DATAMART_BUCKET, Key='datamart_graph/word_graph.json', Body=json.dumps(graph))
    return {'statusCode': 200, 'body': "Grafo actualizado"}
""",
        'stat_builder': """
import boto3
import json

s3 = boto3.client('s3')
EVENTS_BUCKET = 'project-events'
DATAMART_BUCKET = 'project-datamarts'

def lambda_handler(event, context):
    response = s3.list_objects_v2(Bucket=EVENTS_BUCKET)
    events = []
    for obj in response.get('Contents', []):
        event_response = s3.get_object(Bucket=EVENTS_BUCKET, Key=obj['Key'])
        events.extend(json.loads(event_response['Body'].read().decode('utf-8')))
    stats = {'total_events': len(events)}
    s3.put_object(Bucket=DATAMART_BUCKET, Key='datamart_stats/stats.json', Body=json.dumps(stats))
    return {'statusCode': 200, 'body': "Estadísticas actualizadas"}
"""
    }

    for function_name, code in lambdas_code.items():
        zip_path = create_lambda_zip(function_name, code)
        create_lambda_function(function_name, role_arn, zip_path)


# Ejecutar la configuración completa
if __name__ == "__main__":
    print("Iniciando configuración de AWS desde cero...")

    # 1. Crear buckets de S3
    create_s3_buckets()

    # 2. Crear un rol para Lambda
    lambda_role_arn = create_lambda_execution_role()

    # 3. Crear funciones Lambda y configurarlas
    if lambda_role_arn:
        create_all_lambdas(lambda_role_arn)

        # Configurar eventos de S3 para disparar las Lambdas
        for function_name in FUNCTIONS:
            lambda_arn = lambda_client.get_function(FunctionName=function_name)['Configuration']['FunctionArn']
            if function_name == 'dictionary_builder':
                configure_s3_notifications(DATALAKE_BUCKET, lambda_arn, '.txt')

    print("Infraestructura inicial configurada exitosamente.")
