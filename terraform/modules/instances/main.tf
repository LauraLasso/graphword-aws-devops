data "aws_caller_identity" "current" {}

# Obtener la VPC predeterminada
data "aws_vpc" "default" {
  default = true
}

# Obtener todas las subnets asociadas a la VPC
data "aws_subnets" "all_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Filtrar automáticamente solo las subnets públicas y seleccionar las 2 primeras
locals {
  account_id   = data.aws_caller_identity.current.account_id
  public_subnets = [
    for subnet_id in data.aws_subnets.all_subnets.ids :
    subnet_id if element([true, false], 0)  # Simular filtro `map_public_ip_on_launch == true`
  ]

  selected_public_subnets = slice(local.public_subnets, 0, 2)
}

# Grupo de seguridad para el ALB (Application Load Balancer)
resource "aws_security_group" "alb_sg" {
  name        = "ALB_SG"
  description = "Grupo de seguridad para el ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80  # Puerto para tráfico HTTP
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Tráfico público de internet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Permite cualquier tráfico de salida
  }
}

# Security Group para las instancias EC2
resource "aws_security_group" "api_ssh_group" {
  name        = "API_SSH_Group"
  description = "Grupo de seguridad para API y SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Crear 6 instancias EC2
# resource "aws_instance" "instances" {
#   count         = 6
#   ami           = "ami-01816d07b1128cd2d"  # AMI base
#   instance_type = "t2.micro"
#   key_name      = "vockey"

#   security_groups = [aws_security_group.api_ssh_group.name]

#   iam_instance_profile = "LabInstanceProfile"

#   user_data = file("../scripts/instance_${count.index + 1}.sh")

#   tags = {
#     Name = "EC2Instance-${count.index + 1}"
#   }
# }

# Crear instancias 1, 2, 3, 5 y 6 (omitiendo la 4)
resource "aws_instance" "other_instances" {
  count         = 5  # Creamos 5 instancias (saltamos la 4)
  ami           = "ami-01816d07b1128cd2d"  # AMI base para las instancias
  instance_type = "t2.micro"
  key_name      = "vockey"

  subnet_id = element(local.selected_public_subnets, count.index % length(local.selected_public_subnets))

  # Cambiado a `vpc_security_group_ids`
  vpc_security_group_ids = [aws_security_group.api_ssh_group.id]

  iam_instance_profile = "LabInstanceProfile"

  # Crear una lista de índices y excluir el índice 3 (instancia 4)
  user_data = replace(
    replace(
      replace(
        replace(
          replace(
            file("../scripts/instance_${element([0, 1, 2, 4, 5], count.index) + 1}.sh"),
            "{{ datalake_graph_bucket }}", "${var.datalake_graph_bucket}${var.suffix_number}"
          ),
          "{{ datamart_dictionary_bucket }}", "${var.datamart_dictionary_bucket}${var.suffix_number}"
        ),
        "{{ datamart_graph_bucket }}", "${var.datamart_graph_bucket}${var.suffix_number}"
      ),
      "{{ datamart_stats_bucket }}", "${var.datamart_stats_bucket}${var.suffix_number}"
    ),
    "{{ code_bucket }}", "${var.code_bucket}${var.suffix_number}"
  )


  tags = {
    Name = "EC2Instance-${element([0, 1, 2, 4, 5], count.index) + 1}"
  }
}


# Crear 4 instancias EC2 idénticas a la instancia 4 con `user_data`
resource "aws_instance" "instance4_clones" {
  count         = 4  # Crear 4 instancias idénticas
  ami           = "ami-01816d07b1128cd2d"  # AMI base de la instancia 4
  instance_type = "t2.micro"
  key_name      = "vockey"

  subnet_id     = element(local.selected_public_subnets, count.index % length(local.selected_public_subnets))

  # Cambiado a `vpc_security_group_ids`
  vpc_security_group_ids = [aws_security_group.api_ssh_group.id]

  iam_instance_profile = "LabInstanceProfile"

  # user_data = templatefile("${path.module}/../scripts/instance_4.sh", {
  #   code_bucket           = "${var.code_bucket}${var.suffix_number}",
  #   datalake_graph_bucket        = "${var.datalake_graph_bucket}${var.suffix_number}",
  #   datamart_dictionary_bucket   = "${var.datamart_dictionary_bucket}${var.suffix_number}",
  #   datamart_graph_bucket  = "${var.datamart_graph_bucket}${var.suffix_number}",
  #   datamart_stats_bucket  = "${var.datamart_stats_bucket}${var.suffix_number}"
  # })

  user_data = replace(
    replace(
      replace(
        replace(
          replace(
            file("../scripts/instance_4.sh"),
            "{{ datalake_graph_bucket }}", "${var.datalake_graph_bucket}${var.suffix_number}"
          ),
          "{{ datamart_dictionary_bucket }}", "${var.datamart_dictionary_bucket}${var.suffix_number}"
        ),
        "{{ datamart_graph_bucket }}", "${var.datamart_graph_bucket}${var.suffix_number}"
      ),
      "{{ datamart_stats_bucket }}", "${var.datamart_stats_bucket}${var.suffix_number}"
    ),
    "{{ code_bucket }}", "${var.code_bucket}${var.suffix_number}"
  )


    # Script `user_data` usado en la instancia 4 para ejecutar la API

  tags = {
    Name = "EC2-Instance4-Clone-${count.index + 1}"
  }
}

# Launch Template para el Auto Scaling Group (ASG)
# resource "aws_launch_template" "api_launch_template" {
#   name          = "api-launch-template"
#   image_id      = aws_ami_from_instance.instance4_ami.id
#   instance_type = "t2.micro"
#   key_name      = "vockey"

#   network_interfaces {
#     associate_public_ip_address = true
#     security_groups              = [aws_security_group.api_ssh_group.id]
#   }

#   tags = {
#     Name = "API-Instance"
#   }
# }

# Crear el Load Balancer (ALB)
resource "aws_lb" "api_lb" {
  name               = "api-load-balancer"
  internal           = false  # Load Balancer público
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]  # Usar el grupo de seguridad del ALB
  subnets            = local.public_subnets
}

# Target Group para el ALB
resource "aws_lb_target_group" "api_target_group" {
  name     = "api-target-group"
  port     = 8080  # Puerto donde corre la API
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/health"  # Ruta de chequeo de salud
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener del ALB
resource "aws_lb_listener" "api_listener" {
  load_balancer_arn = aws_lb.api_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_target_group.arn
  }
}

# Asociar instancias EC2 al Target Group
resource "aws_lb_target_group_attachment" "ec2_targets" {
  count            = length(aws_instance.instance4_clones.*.id)  # 4 instancias creadas
  target_group_arn = aws_lb_target_group.api_target_group.arn
  target_id        = aws_instance.instance4_clones[count.index].id
  port             = 8080
}

# Auto Scaling Group (ASG)
# resource "aws_autoscaling_group" "api_asg" {
#   desired_capacity    = 2
#   max_size            = 5
#   min_size            = 2
#   vpc_zone_identifier = local.selected_public_subnets  # Solo las primeras 2 subnets públicas

#   service_linked_role_arn = "arn:aws:iam::${local.account_id}:role/AWSServiceRoleForAutoScaling"

#   launch_template {
#     id      = aws_launch_template.api_launch_template.id
#     version = "$Latest"
#   }

#   target_group_arns = [aws_lb_target_group.api_target_group.arn]

#   tag {
#     key                 = "Name"
#     value               = "API-ASG-Instance"
#     propagate_at_launch = true
#   }
# }