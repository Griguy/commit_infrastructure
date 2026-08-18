variable "project_name" {
  description = "Name of the project, used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "service_name" {
  description = "Short name for the service this pipeline builds, e.g. \"backend\""
  type        = string
}

variable "github_owner" {
  description = "GitHub org/user that owns the source repo"
  type        = string
  default     = "Griguy"
}

variable "github_repo" {
  description = "GitHub repo name (without owner), e.g. \"commit_backend\""
  type        = string
}

variable "branch" {
  description = "Branch to build from"
  type        = string
  default     = "dev"
}

variable "ecr_repository_url" {
  description = "URL of the ECR repository this pipeline pushes images to"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository this pipeline pushes images to"
  type        = string
}

variable "codestar_connection_arn" {
  description = "ARN of the CodeStar Connections GitHub connection used as the pipeline's source"
  type        = string
}

variable "gitops_deploy_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the GitOps repo deploy key/PAT"
  type        = string
}

variable "gitops_repo_url" {
  description = "SSH URL of the GitOps repo CodeBuild pushes image-tag bumps to"
  type        = string
  default     = "git@github.com:Griguy/commit_gitops.git"
}

variable "codebuild_image" {
  description = "CodeBuild build environment image"
  type        = string
  default     = "aws/codebuild/standard:7.0"
}

variable "codebuild_compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}
