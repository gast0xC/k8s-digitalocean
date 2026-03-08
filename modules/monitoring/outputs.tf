output "grafana_url" {
  description = "Grafana hostname"
  value       = "grafana.${var.base_domain}"
}
