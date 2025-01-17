output "api_graph_query_url" {
  description = "URL de la API para consultas de grafos"
  value       = module.instances.api_dns_load_balancer
}

output "api_stat_query_url" {
  description = "URL de la API para consultas de estadísticas"
  value       = module.instances.api_stat_query_url
}

output "datalake_bucket_name" {
  description = "Nombre completo del bucket de datalake"
  value = "${var.datalake_graph_bucket}${var.suffix_number}"
}
