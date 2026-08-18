data "aws_region" "current" {}

# Unlike the Helm v3 provider (which nests its Kubernetes config under a
# single `kubernetes = { ... }` object attribute), the Kubernetes provider
# still exposes `host`/`cluster_ca_certificate` as top-level attributes and
# `exec` as its own nested block -- confirmed against the v3.2.1 provider
# schema rather than assumed from the Helm provider's shape.
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", data.aws_region.current.region]
  }
}

resource "kubernetes_namespace_v1" "backend" {
  metadata {
    name = "backend"
  }
}

# kubernetes_secret_v1 base64-encodes `data` values itself -- passing
# already base64-encoded strings here would double-encode them and the
# backend pod would read garbage back out.
resource "kubernetes_secret_v1" "db" {
  metadata {
    name      = "cm-backend-db"
    namespace = kubernetes_namespace_v1.backend.metadata[0].name
  }

  data = {
    DB_HOST     = var.db_host
    DB_PORT     = tostring(var.db_port)
    DB_NAME     = var.db_name
    DB_USER     = var.db_username
    DB_PASSWORD = var.db_password
  }
}
