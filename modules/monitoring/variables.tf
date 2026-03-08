variable "base_domain" {
  type        = string
  description = "Base domain (e.g. gast-k8s.me)"
}

variable "domain_id" {
  type        = string
  description = "DigitalOcean domain ID from the ingress module"
}

variable "ingress_ip" {
  type        = string
  description = "Public IP of the nginx ingress load balancer"
}

variable "cluster_issuer" {
  type        = string
  description = "Name of the cert-manager ClusterIssuer to use for TLS"
}
