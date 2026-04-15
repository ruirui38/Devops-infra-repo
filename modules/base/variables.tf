variable "project_name" {
  description = "プロジェクト名"

  type = string
}

variable "vpc_cidr" {
  description = "VPCのCIDR"

  type = string

  default = "10.0.0.0/21"
}

variable "availability_zone" {
  description = "AZ"

  type = list(string)
}

variable "db_name" {
  description = "DB名"

  type = string
}

variable "db_user" {
  description = "DBユーザー名"

  type = string
}

variable "db_password" {
  description = "DBパスワード"

  type = string
}
