variable "region" {
  description = "Región donde se crearán los recursos"
  type        = string
  default     = "us-east-1"
}

variable "datalake_graph_bucket" {
  description = "Nombre del bucket para datalake-graph"
  type        = string
  default     = "datalake-graph-ulpgc"
}

variable "datamart_dictionary_bucket" {
  description = "Nombre del bucket para datamart-dictionary"
  type        = string
  default     = "datamart-dictionary-ulpgc"
}

variable "datamart_graph_bucket" {
  description = "Nombre del bucket para datamart-graph"
  type        = string
  default     = "datamart-graph-ulpgc"
}

variable "datamart_stats_bucket" {
  description = "Nombre del bucket para datamart-stats"
  type        = string
  default     = "datamart-stats-ulpgc"
}

variable "code_bucket" {
  description = "Nombre del bucket para los archivos de código"
  type        = string
  default     = "graph-code-bucket-ulpgc"
}

variable "suffix_number" {
  description = "Número de sufijo dinámico para los buckets"
  default     = "02"
}

variable "environment" {
  description = "Entorno de despliegue (e.g., dev, staging, prod)"
  type        = string
  default     = "production"  # Valor por defecto: production
}

