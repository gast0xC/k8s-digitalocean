terraform {
  required_version = ">= 1.5"

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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
    # gavinbunney/kubectl does NOT validate CRDs at plan time.
    # This is critical for cert-manager: its CRDs don't exist until
    # the helm chart installs, so kubernetes_manifest would fail at plan.
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }

  # State stored in PostgreSQL. Connection string read from PG_CONN_STR env var.
  # Run `cd ~/dev/proj1 && docker compose up -d` before terraform init.
  backend "pg" {}
}
