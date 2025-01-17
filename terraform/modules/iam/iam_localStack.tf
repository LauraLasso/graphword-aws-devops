# Usar un perfil de instancia existente
# resource "aws_iam_instance_profile" "ec2_instance_profile" {
#   name = var.ec2_instance_role # Usar la variable para definir el perfil de instancia
# }

# NOTA: No se requiere crear un rol ni una política personalizada aquí.
# Se asume que "EC2InstanceRole" ya tiene las políticas necesarias para acceder a S3 u otros servicios.

# Output para referenciar el perfil de instancia en otros módulos o recursos
# output "ec2_instance_profile_name" {
#   value = aws_iam_instance_profile.ec2_instance_profile.name
# }

resource "aws_iam_role" "ec2_role" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_policy" "s3_policy" {
  name        = "${var.project_name}-s3-access"
  description = "Permite acceso a S3 desde las instancias EC2"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["s3:*"],
        Effect   = "Allow",
        Resource = [
          "arn:aws:s3:::${var.datalake_bucket}",
          "arn:aws:s3:::${var.datalake_bucket}/*",
          "arn:aws:s3:::${var.datamart_dictionary_bucket}",
          "arn:aws:s3:::${var.datamart_dictionary_bucket}/*",
          "arn:aws:s3:::${var.datamart_graph_bucket}",
          "arn:aws:s3:::${var.datamart_graph_bucket}/*",
          "arn:aws:s3:::${var.datamart_stats_bucket}",
          "arn:aws:s3:::${var.datamart_stats_bucket}/*",
          "arn:aws:s3:::my-code-bucket",          # Añadido el bucket my-code-bucket
          "arn:aws:s3:::my-code-bucket/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# # output "ec2_instance_profile_name" {
# #   value = aws_iam_instance_profile.ec2_instance_profile.name
# # }