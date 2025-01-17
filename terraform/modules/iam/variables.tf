# variable "ec2_instance_role" {
#   description = "Nombre del perfil de instancia predeterminado que se usará en las instancias EC2."
#   type        = string
#   default     = "EC2InstanceRole" # Asegúrate de que este rol existe y tiene permisos necesarios
# }

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "datalake_bucket" {
  description = "Nombre del bucket del datalake"
  type        = string
}

variable "datamart_dictionary_bucket" {
  description = "Nombre del bucket del datamart para diccionarios"
  type        = string
}

variable "datamart_graph_bucket" {
  description = "Nombre del bucket del datamart para grafos"
  type        = string
}

variable "datamart_stats_bucket" {
  description = "Nombre del bucket del datamart para estadísticas"
  type        = string
}