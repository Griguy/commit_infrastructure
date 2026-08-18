variable "project_name" {
  description = "Name of the project, used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "secret_name" {
  description = "Name of the Secrets Manager secret"
  type        = string
  default     = "gitops-deploy-key"
}
