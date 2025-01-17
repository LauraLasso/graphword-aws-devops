provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

module "buckets_and_queues" {
  source = "./modules/buckets_and_queues"

  datalake_graph_bucket   = var.datalake_graph_bucket
  datamart_dictionary_bucket = var.datamart_dictionary_bucket
  datamart_graph_bucket   = var.datamart_graph_bucket
  datamart_stats_bucket   = var.datamart_stats_bucket
  code_bucket             = var.code_bucket
  region                  = var.region
  suffix_number           = var.suffix_number
  environment             = var.environment
}

module "instances" {
  source = "./modules/instances"

  datalake_graph_bucket   = var.datalake_graph_bucket
  datamart_dictionary_bucket = var.datamart_dictionary_bucket
  datamart_graph_bucket   = var.datamart_graph_bucket
  datamart_stats_bucket   = var.datamart_stats_bucket
  code_bucket             = var.code_bucket
  region                  = var.region
  suffix_number           = var.suffix_number
  environment             = var.environment

  depends_on = [
    module.buckets_and_queues
  ]
}
