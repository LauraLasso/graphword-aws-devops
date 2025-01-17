variable "region" {
  description = "Región donde se crearán los recursos"
  type        = string
  default     = "us-east-1"
}

variable "datalake_graph_bucket_name" {
  description = "Nombre del bucket para datalake-graph"
  type        = string
  default     = "datalake-graph-ulpgc3"
}

variable "datamart_dictionary_bucket_name" {
  description = "Nombre del bucket para datamart-dictionary"
  type        = string
  default     = "datamart-dictionary-ulpgc3"
}

variable "datamart_graph_bucket_name" {
  description = "Nombre del bucket para datamart-graph"
  type        = string
  default     = "datamart-graph-ulpgc3"
}

variable "datamart_stats_bucket_name" {
  description = "Nombre del bucket para datamart-stats"
  type        = string
  default     = "datamart-stats-ulpgc3"
}

variable "code_bucket_name" {
  description = "Nombre del bucket para los archivos de código"
  type        = string
  default     = "graph-code-bucket-ulpgc3"
}
