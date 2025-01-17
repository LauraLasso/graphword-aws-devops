output "api_graph_query_url" {
  description = "API URL for graph queries"
  value       = module.instances.api_dns_load_balancer
}

output "api_stat_query_url" {
  description = "API URL for statistics queries"
  value       = module.instances.api_stat_query_url
}

output "datalake_bucket_name" {
  description = "Full name of the datalake bucket"
  value       = "${var.datalake_graph_bucket}${var.suffix_number}"
}