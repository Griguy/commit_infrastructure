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
