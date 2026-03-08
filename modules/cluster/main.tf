terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}

# The Kubernetes cluster running on DigitalOcean (DOKS).
# DOKS is a managed Kubernetes service — DigitalOcean manages the control plane
# (API server, etcd, scheduler) and you manage the worker nodes (the node pool).
resource "digitalocean_kubernetes_cluster" "main" {
  name    = var.cluster_name
  region  = var.region
  # Kubernetes version — check `doctl kubernetes options versions` for available versions
  version = "1.35.1-do.0"

  # Node pool: the worker nodes that run your pods.
  # Autoscaling means DigitalOcean adds/removes nodes based on resource demand.
  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-2gb" # 2 vCPUs, 2GB RAM — $18/month per node
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 3
  }

  # Maintenance window: cluster upgrades happen Sunday at 2am UTC
  maintenance_policy {
    start_time = "02:00"
    day        = "sunday"
  }
}
