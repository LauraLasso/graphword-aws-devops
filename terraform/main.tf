provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

module "buckets_and_queues" {
  source = "./modules/buckets_and_queues"

  datalake_graph_bucket_name   = var.datalake_graph_bucket_name
  datamart_dictionary_bucket_name = var.datamart_dictionary_bucket_name
  datamart_graph_bucket_name   = var.datamart_graph_bucket_name
  datamart_stats_bucket_name   = var.datamart_stats_bucket_name
  code_bucket_name             = var.code_bucket_name
  region                       = var.region
}

module "instances" {
  source = "./modules/instances"

  depends_on = [
    module.buckets_and_queues
  ]
}
