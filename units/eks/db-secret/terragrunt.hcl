include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

include "inputs" {
  path = find_in_parent_folders("unit_configs/eks/db-secret/config.hcl")
}

dependency "eks" {
  config_path = ".."
}

dependency "rds" {
  config_path = "../../rds"
}

locals {
  modules_source = include.root.locals.modules_source
  module_version = try(values.version, include.root.locals.modules_base_version)

  # Smart checker: versioning not a git repo is incorrect
  ref_part = strcontains(local.modules_source, ".git") ? "?ref=${local.module_version}" : ""
}

terraform {
  source = "${local.modules_source}/eks/db-secret${local.ref_part}"
}

inputs = {
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data

  db_host     = dependency.rds.outputs.db_address
  db_port     = dependency.rds.outputs.db_port
  db_name     = dependency.rds.outputs.db_name
  db_username = dependency.rds.outputs.db_username
  db_password = dependency.rds.outputs.db_password
}
