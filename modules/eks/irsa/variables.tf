variable "project_name" {
  description = "Name of the project, used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC identity provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "Cluster OIDC issuer, without the https:// scheme"
  type        = string
}

variable "roles" {
  description = "IRSA roles to create, keyed by a short name used in the role name and as the output key"
  type = map(object({
    namespace            = string
    service_account_name = string
    policy_arns          = list(string)
  }))
}
