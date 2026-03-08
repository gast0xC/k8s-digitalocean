terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}

# DNS record: grafana.gast-k8s.me → ingress IP
# nginx ingress routes requests with Host: grafana.gast-k8s.me to the Grafana service
resource "digitalocean_record" "grafana" {
  domain = var.domain_id
  type   = "A"
  name   = "grafana"
  value  = var.ingress_ip
}

# kube-prometheus-stack bundles three tools:
#
#   Prometheus — time-series metrics database
#     Scrapes metrics from all your pods, nodes and k8s components every 15s.
#     Stores them locally. Provides a query language (PromQL) to query them.
#
#   Grafana — visualization
#     Connects to Prometheus as a data source.
#     Provides dashboards for CPU, memory, pod status, network, etc.
#     The stack ships pre-built dashboards for Kubernetes out of the box.
#
#   Alertmanager — alerting
#     Receives alerts from Prometheus rules and routes them to Slack, email, etc.
#
#   Also includes:
#     kube-state-metrics — exposes k8s object state as metrics (pod restarts, etc.)
#     node-exporter — exposes node-level metrics (disk, CPU, RAM per node)
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
            # cert-manager sees this annotation and automatically provisions
            # a TLS certificate from Let's Encrypt for this Ingress
            "cert-manager.io/cluster-issuer" = var.cluster_issuer
          }
          hosts = ["grafana.${var.base_domain}"]
          tls = [
            {
              # cert-manager creates this Secret with the certificate + private key.
              # nginx reads the Secret and serves HTTPS.
              secretName = "grafana-tls"
              hosts      = ["grafana.${var.base_domain}"]
            }
          ]
        }
      }
    })
  ]
}
