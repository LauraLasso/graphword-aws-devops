data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "all_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  public_subnets = [
    for subnet_id in data.aws_subnets.all_subnets.ids :
    subnet_id if element([true, false], 0) 
  ]

  selected_public_subnets = slice(local.public_subnets, 0, 2)
}

resource "aws_security_group" "alb_sg" {
  name        = "ALB_SG"
  description = "Grupo de seguridad para el ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80  
    to_port     = 80
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

resource "aws_instance" "other_instances" {
  count         = 5  
  ami           = "ami-01816d07b1128cd2d"  
  instance_type = "t2.micro"
  key_name      = "vockey"

  subnet_id = element(local.selected_public_subnets, count.index % length(local.selected_public_subnets))

  vpc_security_group_ids = [aws_security_group.api_ssh_group.id]

  iam_instance_profile = "LabInstanceProfile"

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


resource "aws_instance" "instance4_clones" {
  count         = 4  
  ami           = "ami-01816d07b1128cd2d"  
  instance_type = "t2.micro"
  key_name      = "vockey"

  subnet_id     = element(local.selected_public_subnets, count.index % length(local.selected_public_subnets))

  vpc_security_group_ids = [aws_security_group.api_ssh_group.id]

  iam_instance_profile = "LabInstanceProfile"

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

  tags = {
    Name = "EC2-Instance4-Clone-${count.index + 1}"
  }
}


resource "aws_lb" "api_lb" {
  name               = "api-load-balancer"
  internal           = false  
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]  
  subnets            = local.public_subnets
}

resource "aws_lb_target_group" "api_target_group" {
  name     = "api-target-group"
  port     = 8080  
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/health"  
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "api_listener" {
  load_balancer_arn = aws_lb.api_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_target_group.arn
  }
}

resource "aws_lb_target_group_attachment" "ec2_targets" {
  count            = length(aws_instance.instance4_clones.*.id)  
  target_group_arn = aws_lb_target_group.api_target_group.arn
  target_id        = aws_instance.instance4_clones[count.index].id
  port             = 8080
}