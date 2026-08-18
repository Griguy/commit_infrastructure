variable "project_name" {
  description = "Name of the project, used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "repository_names" {
  description = "ECR repositories to create"
  type        = list(string)
}

variable "untagged_image_expiry_days" {
  description = "Days after which untagged images are expired by the lifecycle policy"
  type        = number
  default     = 7
}
