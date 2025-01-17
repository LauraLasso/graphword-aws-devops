provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

module "buckets_and_queues" {
  source = "./modules/buckets_and_queues"

  functional_buckets = var.functional_buckets
  code_bucket        = var.code_bucket
  region             = var.region
}

module "instances" {
  source = "./modules/instances"

  code_bucket        = var.code_bucket
  functional_buckets = var.functional_buckets

  depends_on = [
    module.buckets_and_queues
  ]
}