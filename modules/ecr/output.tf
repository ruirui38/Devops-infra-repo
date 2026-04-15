output "ecr_repository_url" {
  description = "ECRリポジトリURL"
  value       = aws_ecr_repository.api.repository_url
}
