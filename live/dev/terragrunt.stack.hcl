locals {
  units_path = find_in_parent_folders("units")
}

unit "vpc" {
  source = "${local.units_path}/vpc"
  path   = "vpc"
}

unit "eks" {
  source = "${local.units_path}/eks"
  path   = "eks"
}

unit "windows" {
  source = "${local.units_path}/windows"
  path   = "windows"
}

unit "rds" {
  source = "${local.units_path}/rds"
  path   = "rds"
}

unit "dns" {
  source = "${local.units_path}/dns"
  path   = "dns"
}

unit "argocd" {
  source = "${local.units_path}/eks/argocd"
  path   = "eks/argocd"
}

unit "irsa" {
  source = "${local.units_path}/eks/irsa"
  path   = "eks/irsa"
}

unit "db-secret" {
  source = "${local.units_path}/eks/db-secret"
  path   = "eks/db-secret"
}

unit "ecr" {
  source = "${local.units_path}/ecr"
  path   = "ecr"
}

unit "codeconnection" {
  source = "${local.units_path}/codeconnection"
  path   = "codeconnection"
}

unit "gitops-credential" {
  source = "${local.units_path}/cicd/gitops-credential"
  path   = "cicd/gitops-credential"
}

unit "cicd-backend" {
  source = "${local.units_path}/cicd/backend"
  path   = "cicd/backend"
}

unit "cicd-frontend" {
  source = "${local.units_path}/cicd/frontend"
  path   = "cicd/frontend"
}
