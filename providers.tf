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
    # Used to wait for cert-manager CRDs to register before creating ClusterIssuer
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
    # Unlike kubernetes_manifest, kubectl_manifest does NOT validate CRDs at plan time.
    # This lets us create the ClusterIssuer after cert-manager installs its CRDs.
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
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

provider "time" {}

provider "kubectl" {
  host                   = module.cluster.cluster_data.host
  token                  = module.cluster.cluster_data.token
  cluster_ca_certificate = module.cluster.cluster_data.cluster_ca_certificate
  load_config_file       = false
}
