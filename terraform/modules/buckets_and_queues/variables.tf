variable "functional_buckets" {
  description = "Lista de buckets funcionales"
  type        = list(string)
  default = [
    "datalake-graph-ulpgc4",
    "datamart-dictionary-ulpgc4",
    "datamart-graph-ulpgc4",
    "datamart-stats-ulpgc4"
  ]
}

variable "code_bucket" {
  description = "Bucket para almacenar archivos de código"
  type        = string
  default     = "graph-code-bucket-ulpgc4"
}

variable "region" {
  description = "Región donde se crearán los recursos"
  type        = string
  default     = "us-east-1"
}

variable "datalake_bucket" {
  description = "Nombre del bucket del datalake"
  type        = string
  default     = "datalake-graph-ulpgc4"
}