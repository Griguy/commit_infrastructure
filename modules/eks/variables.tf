variable "project_name" {
  description = "Name of the project, used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  description = "ID of the VPC the cluster and its nodes run in"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the EKS cluster's VPC config"
  type        = list(string)
}
