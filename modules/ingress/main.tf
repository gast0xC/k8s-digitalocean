terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    helm = {
      source = "hashicorp/helm"
      version = "3.1.1"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

resource "helm_release" "ingres-nginx" {
    repository = "https://kubernetes.github.io/ingress-nginx"
    chart = "ingress-nginx"
    name = "ingress-nginx"
    namespace = "ingress-nginx"
    create_namespace = true

    set = [
        {
            name  = "controller.ingressClassResource.default"
            value = "true"
        }
    ]
}

data "kubernetes_service_v1" "ingress-nginx" {
    metadata {
        name = "${helm_release.ingres-nginx.name}-controller"
        namespace = helm_release.ingres-nginx.namespace
    }

    depends_on = [helm_release.ingres-nginx]
}
variable "base_domain" {
    type = string
    default = "gast-k8s.me"
}


variable "sub_domain" {
    type = string
}

resource "digitalocean_domain" "main" {
    name = var.base_domain
}

resource "digitalocean_record" "www" {
  domain = digitalocean_domain.main.id
  type   = "A"
  name   = var.sub_domain
  value  = data.kubernetes_service_v1.ingress-nginx.status[0].load_balancer[0].ingress[0].ip
}