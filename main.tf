module "cluster" {
  source       = "./modules/cluster"
  cluster_name = "my-amazing-cluster"
  region       = "nyc3"
}

locals {
  base_domain = "gast-k8s.me"
}

# ============================================================
# INGRESS
# Provisions nginx ingress controller + DigitalOcean domain
# Outputs: domain_id, ingress_ip
# ============================================================
module "ingress" {
  source      = "./modules/ingress"
  base_domain = local.base_domain
}

# DNS A records — all subdomains point to the same ingress IP.
# nginx routes traffic to the right service based on the hostname.
resource "digitalocean_record" "grafana" {
  domain = module.ingress.domain_id
  type   = "A"
  name   = "grafana"
  value  = module.ingress.ingress_ip
}

resource "digitalocean_record" "dashboard" {
  domain = module.ingress.domain_id
  type   = "A"
  name   = "dashboard"
  value  = module.ingress.ingress_ip
}

# ============================================================
# CERT-MANAGER
# Automatically provisions and renews TLS certs from Let's Encrypt.
# How it works:
#   1. cert-manager watches Ingress resources for the annotation
#      cert-manager.io/cluster-issuer: letsencrypt-prod
#   2. It creates a Certificate object and requests a cert from Let's Encrypt
#   3. Let's Encrypt sends an HTTP-01 challenge (a request to /.well-known/acme-challenge/...)
#      which nginx ingress handles automatically
#   4. cert-manager stores the signed cert in a Kubernetes Secret
#   5. nginx picks up the Secret and serves HTTPS
#   6. cert-manager auto-renews 30 days before expiry
# ============================================================
resource "helm_release" "cert_manager" {
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.17.0"

  set = [
    {
      # Install cert-manager's CRDs (Certificate, ClusterIssuer, etc.)
      # CRDs are cluster-wide API extensions — without them the ClusterIssuer below won't exist
      name  = "crds.enabled"
      value = "true"
    }
  ]
}

# Wait 30s after cert-manager installs for its CRDs to register in the cluster API.
# Without this, creating the ClusterIssuer immediately after would fail because
# Kubernetes wouldn't know what a ClusterIssuer is yet.
resource "time_sleep" "wait_for_cert_manager" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

# ClusterIssuer tells cert-manager WHERE to get certificates from.
# We use Let's Encrypt production (free, trusted by all browsers).
# The http01 solver means Let's Encrypt verifies domain ownership by making
# an HTTP request to your domain — nginx ingress handles this automatically.
resource "kubectl_manifest" "cluster_issuer" {
  depends_on = [time_sleep.wait_for_cert_manager]

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  })
}

# ============================================================
# HEADLAMP — Kubernetes dashboard
# Accessible at https://dashboard.gast-k8s.me
# ============================================================
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
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        hosts = [
          {
            host = "dashboard.${local.base_domain}"
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
            hosts      = ["dashboard.${local.base_domain}"]
          }
        ]
      }
    })
  ]
}

# ============================================================
# KUBE-PROMETHEUS-STACK — Prometheus + Grafana + Alertmanager
# Accessible at https://grafana.gast-k8s.me
# ============================================================
resource "helm_release" "kube_prometheus_stack" {
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  name             = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  values = [
    yamlencode({
      grafana = {
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
          }
          hosts = ["grafana.${local.base_domain}"]
          tls = [
            {
              secretName = "grafana-tls"
              hosts      = ["grafana.${local.base_domain}"]
            }
          ]
        }
      }
    })
  ]
}
