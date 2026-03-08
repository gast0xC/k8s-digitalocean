output "cluster_issuer_name" {
  description = "Name of the ClusterIssuer. Add as annotation cert-manager.io/cluster-issuer on any Ingress to get a TLS cert."
  value       = kubectl_manifest.cluster_issuer.name
}
