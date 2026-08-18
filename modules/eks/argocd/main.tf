data "aws_region" "current" {}

provider "helm" {
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", data.aws_region.current.region]
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  # The subnets here have no NAT/IGW, so nothing scheduled in the cluster
  # can reach an image registry yet -- pods from this release won't reach
  # Ready until that's resolved. Don't block apply on release readiness in
  # the meantime.
  wait = false
}
