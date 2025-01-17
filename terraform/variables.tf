variable "functional_buckets" {
  description = "Lista de buckets funcionales"
  type        = list(string)
  default = [
    "datalake-graph-ulpgc3",
    "datamart-dictionary-ulpgc3",
    "datamart-graph-ulpgc3",
    "datamart-stats-ulpgc3"
  ]
}

variable "code_bucket" {
  description = "Bucket para almacenar archivos de código"
  type        = string
  default     = "graph-code-bucket-ulpgc3"
}

variable "region" {
  description = "Región donde se crearán los recursos"
  type        = string
  default     = "us-east-1"
}