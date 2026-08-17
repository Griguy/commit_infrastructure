include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

include "env" {
  path = find_in_parent_folders("env.hcl")
  expose = true
}

include "inputs" {
  path = find_in_parent_folders("unit_configs/eks/config.hcl")
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate", "init"]
}

locals {
  modules_source = include.root.locals.modules_source
  module_version = try(values.version, include.root.locals.modules_base_version)

  # Smart checker: versioning not a git repo is incorrect
  ref_part = strcontains(local.modules_source, ".git") ? "?ref=${local.module_version}" : ""
}

terraform {
  source = "${local.modules_source}/eks${local.ref_part}"
}

inputs = {
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnet_ids
}
