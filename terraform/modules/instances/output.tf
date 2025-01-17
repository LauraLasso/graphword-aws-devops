output "api_dns_load_balancer" {
  description = "DNS del Load Balancer para acceder a la API"
  value       = "http://${aws_lb.api_lb.dns_name}"
}

output "api_stat_query_url" {
  description = "URL de la API para consultas de estadísticas"
  value       = "http://${aws_instance.other_instances[4].public_ip}:8080"
}
