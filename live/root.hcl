locals {
  # Region every actual resource gets provisioned into.
  region = "eu-central-1"

  # Region the Terraform state bucket itself lives in -- independent of
  # `region` above. Moving where resources get provisioned (e.g. to a
  # different region for the whole stack) doesn't mean the state bucket
  # moves with them; it was created once, out of band, and stays put.
  state_bucket_region = "us-east-2"

  # Unit dependency relative paths are prediclable
  dependency_paths = {
    for unit in [
      "vpc",
      "eks"
    ] :
    "${unit}" => "../${unit}"
  }

  #NOTE
  # This is I copied one of my existing terragrunt setups, where I made use of such a config.
  # And I decided to just comment out some pieces, instead of purging them out.
  
  # Use TG_MODULE_MODE env to quickly switch between modules source location.
  # Accepted options: "ssh" (default), "https", "local"
  module_mode = get_env("TG_MODULE_MODE", "local")

  module_sources = {
    #"ssh"   = "git::ssh://git@github.com/WT-In/terraform-modules.git//modules"
    #"https" = "git::https://github.com/WT-In/terraform-modules.git//modules"
    "local" = find_in_parent_folders("modules/")
  }

  # default to "local" if env value is invalid
  modules_source = lookup(local.module_sources, local.module_mode, local.module_sources["local"])

  # "base" here means "default for this stack"; which is unless units individually override it
  modules_base_version = "main"
}

# Inputs for all units across all environments
inputs = {
  project_name = "commit-lab"
}

# Backend config
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket       = "commit-lab-task-terraform-state"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.state_bucket_region
    encrypt      = true
    use_lockfile = true
  }
}

# Provider configuration
generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite"

  contents = templatefile(
    find_in_parent_folders("provider.tftpl"),
    {
      region = local.region
    }
  )
}
