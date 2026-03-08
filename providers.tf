terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
  }

  backend "pg" {}
  # conn_str is read from PG_CONN_STR environment variable
}

provider "digitalocean" {
  token = var.do_token
}

provider "kubernetes" {
  host                   = module.cluster.cluster_data.host
  token                  = module.cluster.cluster_data.token
  cluster_ca_certificate = module.cluster.cluster_data.cluster_ca_certificate
}

provider "helm" {
  kubernetes = {
    host                   = module.cluster.cluster_data.host
    token                  = module.cluster.cluster_data.token
    cluster_ca_certificate = module.cluster.cluster_data.cluster_ca_certificate
  }
}