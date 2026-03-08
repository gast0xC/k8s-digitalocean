output "domain_id" {
  description = "DigitalOcean domain ID — used by other modules to create DNS records"
  value       = digitalocean_domain.main.id
}

output "ingress_ip" {
  description = "Public IP of the nginx ingress load balancer — all subdomains point here"
  value       = data.kubernetes_service_v1.ingress_nginx.status[0].load_balancer[0].ingress[0].ip
}
