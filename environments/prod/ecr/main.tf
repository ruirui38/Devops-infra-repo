locals {
  env = "prod"

  project_name = "devops-${local.env}"

}

module "ecr" {
  source = "../../../modules/ecr"

  project_name = local.project_name

}
