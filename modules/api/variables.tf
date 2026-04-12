variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "availability_zone" {
  description = "AZ"
  type        = list(string)
}

variable "container_image_tag" {
  description = "ECRイメージタグ"
  type        = string
  default     = "latest"
}

variable "db_name" {
  description = "DB名"
  type        = string
}

variable "db_user" {
  description = "DBユーザー名"
  type        = string
}

variable "db_password" {
  description = "DBパスワード"
  type        = string
}

variable "db_host" {
  description = "DBホスト名"
  type        = string
  default     = "" # 一時的にデフォルト値を設定
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "パブリックサブネットIDリスト"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "プライベートサブネットIDリスト"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALBセキュリティグループID"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECRリポジトリURL"
  type        = string
}

# variable "log_group_name" {
#   description = "CloudWatch LogsグループID"
#   type        = string
# }

