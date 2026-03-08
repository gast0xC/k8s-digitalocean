# These outputs expose cluster credentials to the root module,
# which uses them to configure the kubernetes, helm, and kubectl providers.
# Marked sensitive so they don't appear in plain text in terraform output.

output "host" {
  description = "Kubernetes API server endpoint"
  value       = digitalocean_kubernetes_cluster.main.endpoint
  sensitive   = true
}

output "token" {
  description = "Kubernetes authentication token"
  value       = digitalocean_kubernetes_cluster.main.kube_config[0].token
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-decoded cluster CA certificate for TLS verification"
  value       = base64decode(digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
  sensitive   = true
}

output "cluster_name" {
  description = "Name of the cluster"
  value       = digitalocean_kubernetes_cluster.main.name
}
