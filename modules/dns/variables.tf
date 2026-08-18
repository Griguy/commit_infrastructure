variable "project_name" {
  description = "Name of the project, used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to associate the private hosted zone with"
  type        = string
}

variable "domain_name" {
  description = "Private hosted zone domain (not publicly routable/registered on purpose)"
  type        = string
  default     = "commit-lab.internal"
}

variable "app_hostname" {
  description = "Record label for the frontend app, i.e. \"<app_hostname>.<domain_name>\""
  type        = string
  default     = "lab-commit-task"
}

variable "alb_dns_name" {
  description = "Internal ALB's DNS name, once it exists (from the AWS Load Balancer Controller-provisioned Ingress). The alias A record is only created once this is set."
  type        = string
  default     = null
}

variable "alb_zone_id" {
  description = "Internal ALB's Route 53 hosted zone ID, once it exists. Required alongside alb_dns_name to create the alias A record."
  type        = string
  default     = null
}
