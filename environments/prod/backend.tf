terraform {
  backend "s3" {
    bucket = "devops-test-tfstate-20260409"
    key = "prod/terraform.tfstate"
    region = "ap-northeast-1"
    encrypt = true
    use_lockfile = true
  }
}