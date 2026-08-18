include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

include "inputs" {
  path = find_in_parent_folders("unit_configs/codeconnection/config.hcl")
}

locals {
  modules_source = include.root.locals.modules_source
  module_version = try(values.version, include.root.locals.modules_base_version)

  # Smart checker: versioning not a git repo is incorrect
  ref_part = strcontains(local.modules_source, ".git") ? "?ref=${local.module_version}" : ""
}

terraform {
  source = "${local.modules_source}/codeconnection${local.ref_part}"
}
