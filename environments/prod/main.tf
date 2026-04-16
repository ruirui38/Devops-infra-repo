terraform {
  required_version = ">=1.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"

      version = "~>6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

locals {
  env = "prod"

  project_name = "devops-${local.env}"

  vpc_cidr = "10.0.0.0/21"

  availability_zone = ["ap-northeast-1a", "ap-northeast-1c"]

  container_image_tag = "latest"

  db_name = "tododb"

  db_user = "admin"

}

data "aws_ecr_repository" "api" {
  name = "devops-prod-api"
}

module "base" {
  source = "../../modules/base"

  project_name = local.project_name

  vpc_cidr = local.vpc_cidr

  availability_zone = local.availability_zone

  db_user = local.db_user

  db_password = var.db_password

  db_name = local.db_name
}

# APIモジュール
module "api" {
  source = "../../modules/api"

  project_name = local.project_name

  vpc_id = module.base.vpc_id

  availability_zone = local.availability_zone

  public_subnet_ids = module.base.public_subnet_ids

  private_subnet_ids = module.base.private_subnet_ids

  alb_security_group_id = module.base.alb_security_group_id

  api_security_group_id = module.base.api_security_group_id

  db_name = local.db_name

  db_user = local.db_user

  db_password = var.db_password

  db_host = module.base.rds_endpoint

  ecr_repository_url = data.aws_ecr_repository.api.repository_url

  cloudwatch_log_group_name = module.base.cloudwatch_log_group_name

  alb_logs = module.base.alb_logs

}
