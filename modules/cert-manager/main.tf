terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

# cert-manager automates TLS certificate lifecycle management.
#
# Without cert-manager, you'd manually:
#   1. Generate a certificate signing request
#   2. Send it to Let's Encrypt
#   3. Complete the domain ownership challenge
#   4. Download the certificate
#   5. Create a k8s Secret with the cert
#   6. Configure your Ingress to use it
#   7. Repeat every 90 days when it expires
#
# With cert-manager, you just annotate an Ingress and it handles all of this.

resource "helm_release" "cert_manager" {
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.17.0"

  set = [
    {
      # CRDs (Custom Resource Definitions) extend the Kubernetes API.
      # cert-manager adds new resource types: Certificate, ClusterIssuer,
      # CertificateRequest, etc. Without crds.enabled=true, these types
      # won't exist and you can't create ClusterIssuers.
      name  = "crds.enabled"
      value = "true"
    }
  ]
}

# CRDs take a moment to register in the Kubernetes API after the helm chart installs.
# Without this wait, the ClusterIssuer below would fail because Kubernetes
# wouldn't recognize the ClusterIssuer resource type yet.
resource "time_sleep" "wait_for_crds" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

# A ClusterIssuer defines WHERE to get certificates from and HOW to prove domain ownership.
# This one uses Let's Encrypt via the ACME protocol with an HTTP-01 challenge:
#
#   HTTP-01 challenge flow:
#   1. cert-manager asks Let's Encrypt for a certificate
#   2. Let's Encrypt says "prove you own the domain by serving this token at /.well-known/acme-challenge/<token>"
#   3. cert-manager creates a temporary Ingress that serves the token
#   4. Let's Encrypt fetches the token from your domain (via nginx ingress)
#   5. Verification passes → Let's Encrypt issues the certificate
#   6. cert-manager stores the cert in a Kubernetes Secret
resource "kubectl_manifest" "cluster_issuer" {
  depends_on = [time_sleep.wait_for_crds]

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
        # cert-manager stores the ACME account private key here
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
