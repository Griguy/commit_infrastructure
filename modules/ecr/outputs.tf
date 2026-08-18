output "repositories" {
  description = "Repository name to { repository_url, arn }"
  value = {
    for name, repo in aws_ecr_repository.this : name => {
      repository_url = repo.repository_url
      arn            = repo.arn
    }
  }
}
