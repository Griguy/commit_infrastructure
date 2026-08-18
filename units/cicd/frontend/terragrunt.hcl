include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

include "inputs" {
  path = find_in_parent_folders("unit_configs/cicd/frontend/config.hcl")
}

dependency "ecr" {
  config_path = "../../ecr"
}

dependency "codeconnection" {
  config_path = "../../codeconnection"
}

dependency "gitops_credential" {
  config_path = "../gitops-credential"
}

locals {
  modules_source = include.root.locals.modules_source
  module_version = try(values.version, include.root.locals.modules_base_version)

  # Smart checker: versioning not a git repo is incorrect
  ref_part = strcontains(local.modules_source, ".git") ? "?ref=${local.module_version}" : ""
}

terraform {
  source = "${local.modules_source}/cicd/pipeline${local.ref_part}"
}

inputs = {
  ecr_repository_url       = dependency.ecr.outputs.repositories["cm-frontend"].repository_url
  ecr_repository_arn       = dependency.ecr.outputs.repositories["cm-frontend"].arn
  codestar_connection_arn  = dependency.codeconnection.outputs.connection_arn
  gitops_deploy_secret_arn = dependency.gitops_credential.outputs.secret_arn
}
