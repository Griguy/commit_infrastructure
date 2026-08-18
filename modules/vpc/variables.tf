variable "project_name" {
  description = "Name of the project, used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets, one per subnet"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets that hold the NAT Gateways, one per AZ -- must be the same length as private_subnet_cidrs, since each private subnet routes through the NAT Gateway in the public subnet at the same index (same AZ)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}
