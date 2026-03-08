module "cluster" {
    source = "./modules/cluster"
    cluster_name = "my-amazing-cluster"
    region = "nyc3"
}

locals {
    base_domain = "gast-k8s.me"
    sub_domain = "demo"
}

module "ingress" {
    source = "./modules/ingress"
    base_domain = local.base_domain
    sub_domain = local.sub_domain
}

resource "helm_release" "grafana" {
    repository = "https://grafana-community.github.io/helm-charts"
    chart = "grafana"
    name = "grafana"

    namespace = "grafana"
    create_namespace = true

    set = [
        {
            name  = "ingress.enabled"
            value = "true"
        },
        {
            name  = "ingress.hosts[0]"
            value = "${local.sub_domain}.${local.base_domain}"
        }
    ]
}