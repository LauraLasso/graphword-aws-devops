import boto3
import json
import time

# Configuración
REGION = 'us-east-1'  # Cambiar según tu región
S3_BUCKET = 'project-datalake-datamarts'  # Nombre del bucket S3
EC2_KEY_NAME = 'my-ec2-key'  # Nombre de tu llave EC2
LAMBDA_ROLE_ARN = 'arn:aws:iam::123456789012:role/lambda-execution-role'  # ARN de rol para Lambda

# Inicializar clientes boto3
ec2 = boto3.client('ec2', region_name=REGION)
s3 = boto3.client('s3', region_name=REGION)
lambda_client = boto3.client('lambda', region_name=REGION)
iam = boto3.client('iam', region_name=REGION)


def create_s3_bucket(bucket_name):
    """Crea un bucket S3 para el datalake y los datamarts."""
    print(f"Creando bucket S3: {bucket_name}")
    try:
        s3.create_bucket(
            Bucket=bucket_name,
            CreateBucketConfiguration={'LocationConstraint': REGION}
        )
        print(f"Bucket S3 '{bucket_name}' creado exitosamente.")
    except Exception as e:
        print(f"Error creando bucket: {e}")


def create_ec2_instance(name, script, instance_type='t2.micro'):
    """Crea una instancia EC2 para ejecutar un módulo del proyecto."""
    print(f"Creando instancia EC2 para {name}...")
    try:
        user_data_script = f"""#!/bin/bash
        yum update -y
        yum install -y python3
        pip3 install boto3
        echo "{script}" > {name}.py
        python3 {name}.py
        """
        instance = ec2.run_instances(
            ImageId='ami-0abcdef1234567890',  # AMI de tu región
            InstanceType=instance_type,
            KeyName=EC2_KEY_NAME,
            MinCount=1,
            MaxCount=1,
            UserData=user_data_script,
            TagSpecifications=[
                {
                    'ResourceType': 'instance',
                    'Tags': [{'Key': 'Name', 'Value': name}]
                }
            ]
        )
        instance_id = instance['Instances'][0]['InstanceId']
        print(f"Instancia EC2 '{name}' creada con ID: {instance_id}")
        return instance_id
    except Exception as e:
        print(f"Error creando instancia EC2: {e}")
        return None


def create_lambda_function(function_name, handler_file, role_arn):
    """Crea una función Lambda para manejar la comunicación entre módulos."""
    print(f"Creando función Lambda: {function_name}")
    try:
        with open(handler_file, 'rb') as f:
            code = f.read()
        response = lambda_client.create_function(
            FunctionName=function_name,
            Runtime='python3.8',
            Role=role_arn,
            Handler=f'{handler_file.split(".")[0]}.lambda_handler',
            Code={'ZipFile': code},
            Timeout=30,
            MemorySize=128
        )
        print(f"Función Lambda '{function_name}' creada.")
        return response
    except Exception as e:
        print(f"Error creando función Lambda: {e}")
        return None


def setup_project():
    """Configura toda la infraestructura del proyecto."""
    print("Iniciando configuración del proyecto...")
    
    # Crear bucket S3
    create_s3_bucket(S3_BUCKET)
    
    # Crear instancias EC2
    crawler_script = f'crawler.py'  # Código del crawler
    dictionary_builder_script = f'dictionary-builder.py'  # Código del dictionary-builder
    graph_builder_script = f'graph-builder.py'  # Código del graph-builder
    stat_builder_script = f'stat-builder.py'  # Código del stat-builder
    
    create_ec2_instance('crawler', crawler_script)
    create_ec2_instance('dictionary-builder', dictionary_builder_script)
    create_ec2_instance('graph-builder', graph_builder_script)
    create_ec2_instance('stat-builder', stat_builder_script)
    
    # Crear funciones Lambda
    lambda_event_handler_file = 'lambda_event_handler.zip'  # Archivo ZIP con el código de Lambda
    lambda_stat_handler_file = 'lambda_stat_handler.zip'
    
    create_lambda_function('event-handler', lambda_event_handler_file, LAMBDA_ROLE_ARN)
    create_lambda_function('stat-handler', lambda_stat_handler_file, LAMBDA_ROLE_ARN)

    print("Configuración del proyecto completada.")


if __name__ == "__main__":
    setup_project()