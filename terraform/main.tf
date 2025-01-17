# provider "aws" {
#   region = "us-east-1"
# }

provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  endpoints {
    s3             = "http://127.0.0.1:4566"
    ec2     = "http://localhost:4566"
    sts     = "http://localhost:4566"
    iam = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    sns            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
  }
}


module "network" {
  source = "./modules/vpc"  # Ahora apunta al directorio vpc
  project_name = var.project_name
}

module "s3_buckets" {
  source = "./modules/s3" # Ruta al submódulo S3
  datalake_bucket = var.datalake_bucket
  datamart_dictionary_bucket = var.datamart_dictionary_bucket
  datamart_graph_bucket = var.datamart_graph_bucket
  datamart_stats_bucket = var.datamart_stats_bucket
}

module "iam" {
  source = "./modules/iam" # Ruta al submódulo IAM
  project_name = var.project_name
  datalake_bucket = var.datalake_bucket
  datamart_dictionary_bucket = var.datamart_dictionary_bucket
  datamart_graph_bucket = var.datamart_graph_bucket
  datamart_stats_bucket = var.datamart_stats_bucket
}

module "ec2_instances" {
  source = "./modules/ec2" # Ruta al submódulo EC2
  project_name = var.project_name
  instance_type = var.instance_type
  iam_instance_profile = module.iam.ec2_instance_profile_name
}
