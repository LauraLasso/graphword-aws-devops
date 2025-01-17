variable "region" {
  description = "Region where the resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "datalake_graph_bucket" {
  description = "Name of the bucket for datalake-graph"
  type        = string
  default     = "datalake-graph-ulpgc"
}

variable "datamart_dictionary_bucket" {
  description = "Name of the bucket for datamart-dictionary"
  type        = string
  default     = "datamart-dictionary-ulpgc"
}

variable "datamart_graph_bucket" {
  description = "Name of the bucket for datamart-graph"
  type        = string
  default     = "datamart-graph-ulpgc"
}

variable "datamart_stats_bucket" {
  description = "Name of the bucket for datamart-stats"
  type        = string
  default     = "datamart-stats-ulpgc"
}

variable "code_bucket" {
  description = "Name of the bucket for code files"
  type        = string
  default     = "graph-code-bucket-ulpgc"
}

variable "suffix_number" {
  description = "Dynamic suffix number for the buckets"
  default     = "02"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "production"
}