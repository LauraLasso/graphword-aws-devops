variable "my_code_bucket" {
  description = "Nombre del bucket para almacenar los archivos de código"
  type        = string
  default     = "my-code-bucket"
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