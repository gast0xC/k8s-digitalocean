# All providers are configured here at the root.
# Child modules inherit these — they don't configure providers themselves.
# Provider config requires cluster credentials from module.cluster, so they
# can only live at the root level where module outputs are accessible.

provider "digitalocean" {
  token = var.do_token
}

provider "kubernetes" {
  host                   = module.cluster.host
  token                  = module.cluster.token
  cluster_ca_certificate = module.cluster.cluster_ca_certificate
}

provider "helm" {
  kubernetes = {
    host                   = module.cluster.host
    token                  = module.cluster.token
    cluster_ca_certificate = module.cluster.cluster_ca_certificate
  }
}

provider "time" {}

provider "kubectl" {
  host                   = module.cluster.host
  token                  = module.cluster.token
  cluster_ca_certificate = module.cluster.cluster_ca_certificate
  load_config_file       = false
}
