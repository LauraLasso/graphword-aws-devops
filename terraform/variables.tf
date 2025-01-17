# variable "region" {
#   default = "us-east-1"
# }

variable "region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  default = "t2.micro"
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

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default = "GraphWord"
}