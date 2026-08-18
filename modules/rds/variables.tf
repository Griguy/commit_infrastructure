variable "project_name" {
  description = "Name of the project, used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy the RDS instance into"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks allowed to reach the database. EKS Auto Mode doesn't support Security Groups for Pods (no branch-ENI trunking), so pod-level scoping via security group membership isn't available -- this CIDR list is the tightest boundary actually enforceable at the network layer on this cluster, with the DB's own username/password as the second layer."
  type        = list(string)
}

variable "engine" {
  description = "RDS engine (postgres or mysql)"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Engine version; major-version-only (e.g. \"16\") lets AWS pick the latest supported minor"
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "labcommit"
}

variable "master_username" {
  description = "Master username (avoid reserved words like \"admin\")"
  type        = string
  default     = "labcommit_admin"
}

variable "port" {
  description = "Port the engine listens on"
  type        = number
  default     = 5432
}
