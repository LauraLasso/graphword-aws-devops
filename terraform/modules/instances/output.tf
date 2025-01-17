output "api_dns_load_balancer" {
  description = "DNS of the Load Balancer to access the API"
  value       = "http://${aws_lb.api_lb.dns_name}"
}

output "api_stat_query_url" {
  description = "API URL for statistics queries"
  value       = "http://${aws_instance.other_instances[4].public_ip}:8080"
}