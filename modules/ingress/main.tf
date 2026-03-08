terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}

# nginx Ingress Controller
# An Ingress Controller is a reverse proxy that runs inside the cluster and
# routes external HTTP/HTTPS traffic to the correct internal service.
#
# How traffic flows:
#   Internet → DigitalOcean Load Balancer (public IP)
#           → nginx ingress controller pod
#           → correct k8s Service (based on hostname/path rules in Ingress resources)
#           → your app pods
#
# The Load Balancer is automatically provisioned by DigitalOcean when nginx
# requests a Service of type LoadBalancer.
resource "helm_release" "ingress_nginx" {
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  set = [
    {
      # Make nginx the default IngressClass so Ingress resources don't need
      # to explicitly specify ingressClassName: nginx
      name  = "controller.ingressClassResource.default"
      value = "true"
    }
  ]
}

# Read the nginx Service to get the Load Balancer IP that DigitalOcean assigned.
# This IP is used to create DNS A records for all our subdomains.
data "kubernetes_service_v1" "ingress_nginx" {
  metadata {
    name      = "${helm_release.ingress_nginx.name}-controller"
    namespace = helm_release.ingress_nginx.namespace
  }

  depends_on = [helm_release.ingress_nginx]
}

# Register the base domain in DigitalOcean DNS.
# This lets us create DNS records (A, CNAME, etc.) via Terraform.
# Note: your domain's nameservers must point to DigitalOcean:
#   ns1.digitalocean.com, ns2.digitalocean.com, ns3.digitalocean.com
resource "digitalocean_domain" "main" {
  name = var.base_domain
}
