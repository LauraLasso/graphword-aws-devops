variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
}

variable "iam_instance_profile" {
  description = "Perfil de instancia IAM asociado a las EC2"
  type        = string
}