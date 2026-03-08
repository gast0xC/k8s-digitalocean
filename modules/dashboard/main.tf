terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}

# DNS record: dashboard.gast-k8s.me → ingress IP
resource "digitalocean_record" "dashboard" {
  domain = var.domain_id
  type   = "A"
  name   = "dashboard"
  value  = var.ingress_ip
}

# Headlamp — a modern, CNCF-backed Kubernetes web UI.
# Lets you browse pods, deployments, services, logs, events etc. from a browser.
# Authentication uses Kubernetes service account tokens (RBAC-based).
resource "helm_release" "headlamp" {
  repository       = "https://kubernetes-sigs.github.io/headlamp/"
  chart            = "headlamp"
  name             = "headlamp"
  namespace        = "headlamp"
  create_namespace = true

  values = [
    yamlencode({
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        annotations = {
          "cert-manager.io/cluster-issuer" = var.cluster_issuer
        }
        hosts = [
          {
            host = "dashboard.${var.base_domain}"
            paths = [
              {
                path = "/"
                type = "Prefix"
              }
            ]
          }
        ]
        tls = [
          {
            secretName = "headlamp-tls"
            hosts      = ["dashboard.${var.base_domain}"]
          }
        ]
      }
    })
  ]
}
