resource "aws_instance" "module_instances" {
  count         = 6
  ami           = "ami-0a8e758f5e873d1c1"
  instance_type = var.instance_type
  iam_instance_profile = var.iam_instance_profile
  tags = {
    Name = "${var.project_name}-module-${count.index}"
  }

  user_data = file("${path.module}/user_data.sh")
  # user_data = <<-EOF
  #             #!/bin/bash

  #             sudo su

  #             # Verificar instalación de AWS CLI
  #             if ! command -v aws &> /dev/null; then
  #               echo "aws-cli no está instalado. Abortando."
  #               exit 1
  #             fi

  #             echo "Ejecutando el script"
  #             yum update -y
  #             yum install python3 -y
  #             pip3 install boto3 flask matplotlib networkx


  #             # Listar archivos en el bucket y elegir el correspondiente a la instancia
  #             INDEX=${count.index}
  #             FILES=($(aws s3 ls s3://my-code-bucket/ | awk '{print $4}'))
  #             FILE_TO_RUN=$${FILES[$INDEX]}

  #             # Validar si se encontró un archivo para la instancia
  #             if [ -z "$FILE_TO_RUN" ]; then
  #               echo "No file assigned to this instance. Exiting."
  #               exit 1
  #             fi

  #             # Descargar y ejecutar el archivo seleccionado
  #             aws s3 cp s3://my-code-bucket/$FILE_TO_RUN /home/ec2-user/module.py
  #             python3 /home/ec2-user/module.py &
  #             EOF

}