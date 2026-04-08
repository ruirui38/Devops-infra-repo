# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "devops-test-tfstate-344302550695"
resource "aws_s3_bucket" "tfstate" {
  bucket              = "devops-test-tfstate-344302550695"
  bucket_namespace    = "global"
  force_destroy       = false
  object_lock_enabled = false
  region              = "ap-northeast-1"
  tags                = {}
  tags_all            = {}
}

# __generated__ by Terraform from "devops-test-tfstate-344302550695"
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = "devops-test-tfstate-344302550695"
  mfa    = null
  region = "ap-northeast-1"
  versioning_configuration {
    status = "Enabled"
  }
}
