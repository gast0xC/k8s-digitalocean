terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

variable "cluster_name" {
    type = string
    default = "my-cluster"
}
variable "region" {
    type = string
    default = "nyc3"
}

resource "digitalocean_kubernetes_cluster" "main" {
  name    = var.cluster_name
  region  = var.region
  version = "1.35.1-do.0"

    node_pool {
        name       = "autoscale-worker-pool"
        size       = "s-2vcpu-2gb"
        auto_scale = true
        min_nodes  = 1
        max_nodes  = 3
    }
    maintenance_policy {
    start_time = "02:00"
    day = "sunday"
    }
}

output "cluster_data" {
    value = {
        host = digitalocean_kubernetes_cluster.main.endpoint
        token = digitalocean_kubernetes_cluster.main.kube_config[0].token
        cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
    }

    sensitive = true
}
