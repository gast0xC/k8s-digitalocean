# Outputs are printed after `terraform apply` and accessible via `terraform output`.
# Useful for quickly finding your service URLs without checking the code.

output "grafana_url" {
  description = "Grafana monitoring dashboard"
  value       = "https://${module.monitoring.grafana_url}"
}

output "dashboard_url" {
  description = "Headlamp Kubernetes dashboard"
  value       = "https://${module.dashboard.dashboard_url}"
}

output "cluster_name" {
  description = "DigitalOcean Kubernetes cluster name"
  value       = module.cluster.cluster_name
}

output "ingress_ip" {
  description = "Public IP of the nginx ingress load balancer"
  value       = module.ingress.ingress_ip
}
