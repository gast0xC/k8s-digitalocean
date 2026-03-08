locals {
  base_domain = "gast-k8s.me"
}

# ── Cluster ──────────────────────────────────────────────────────────────────
# Provisions the DigitalOcean Kubernetes cluster and node pool.
module "cluster" {
  source       = "./modules/cluster"
  cluster_name = "my-amazing-cluster"
  region       = "nyc3"
}

# ── Ingress ───────────────────────────────────────────────────────────────────
# Installs nginx ingress controller via Helm and registers the base domain
# in DigitalOcean DNS. All subdomains point to the same ingress load balancer IP;
# nginx routes requests to the correct service based on the hostname.
module "ingress" {
  source      = "./modules/ingress"
  base_domain = local.base_domain
}

# ── TLS / cert-manager ────────────────────────────────────────────────────────
# Installs cert-manager and configures a ClusterIssuer for Let's Encrypt.
# Any Ingress resource annotated with cert-manager.io/cluster-issuer gets a
# free, auto-renewing TLS certificate.
module "cert_manager" {
  source            = "./modules/cert-manager"
  letsencrypt_email = var.letsencrypt_email
}

# ── Monitoring ────────────────────────────────────────────────────────────────
# Deploys kube-prometheus-stack (Prometheus + Grafana + Alertmanager).
# Creates a DNS record and exposes Grafana at https://grafana.<base_domain>.
module "monitoring" {
  source             = "./modules/monitoring"
  base_domain        = local.base_domain
  domain_id          = module.ingress.domain_id
  ingress_ip         = module.ingress.ingress_ip
  cluster_issuer     = module.cert_manager.cluster_issuer_name
}

# ── Dashboard ─────────────────────────────────────────────────────────────────
# Deploys Headlamp, a modern Kubernetes web UI.
# Creates a DNS record and exposes it at https://dashboard.<base_domain>.
module "dashboard" {
  source             = "./modules/dashboard"
  base_domain        = local.base_domain
  domain_id          = module.ingress.domain_id
  ingress_ip         = module.ingress.ingress_ip
  cluster_issuer     = module.cert_manager.cluster_issuer_name
}
