output "region" {
  description = "Región configurada"
  value       = var.region
}


output "datalake_bucket" {
  value = module.s3_buckets.datalake_bucket_name
}

output "datamart_dictionary_bucket" {
  value = module.s3_buckets.datamart_dictionary_bucket_name
}

output "datamart_graph_bucket" {
  value = module.s3_buckets.datamart_graph_bucket_name
}

output "datamart_stats_bucket" {
  value = module.s3_buckets.datamart_stats_bucket_name
}

output "ec2_instance_ips" {
  value = module.ec2_instances.ec2_instance_ips
}
