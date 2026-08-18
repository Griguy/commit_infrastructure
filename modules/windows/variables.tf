variable "project_name" {
  description = "Name of the project, used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy the workstation and SSM interface endpoints into"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs to place the SSM interface endpoints in; the workstation launches into the first one"
  type        = list(string)
}

variable "instance_type" {
  description = "Instance type for the Windows workstation"
  type        = string
  default     = "t3.large"
}

variable "root_volume_size" {
  description = "Root volume size (GiB) for the Windows workstation"
  type        = number
  default     = 50
}
