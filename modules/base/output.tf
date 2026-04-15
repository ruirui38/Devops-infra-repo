output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.vpc.id
}

output "public_subnet_ids" {
  description = "パブリックサブネットIDのリスト"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "プライベートサブネットIDのリスト"
  value       = aws_subnet.private[*].id
}

output "alb_security_group_id" {
  description = "ALB用セキュリティグループID"
  value       = aws_security_group.alb.id
}

output "api_security_group_id" {
  description = "API用セキュリティグループID"
  value       = aws_security_group.api.id
}

output "rds_endpoint" {
  description = "RDSエンドポイント"
  value       = aws_rds_cluster.rds_cluster.endpoint
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Logsグループ名"
  value       = aws_cloudwatch_log_group.api.name
}
