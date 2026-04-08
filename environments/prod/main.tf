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

module "remote" {
  source = "../../modules/remote"
}

locals {
  env = "prod"

  project_name = "devops-${local.env}"

  vpc_cidr = "10.0.0.0/21"

  availability_zone = ["ap-northeast-1a","ap-northeast-1c"]

  db_name = "tododb"

  db_user = "admin"
}

module "base" {
  source = "../../modules/base"

  project_name = local.project_name

  vpc_cidr = local.vpc_cidr

  availability_zone = local.availability_zone

  db_name = local.db_name
}