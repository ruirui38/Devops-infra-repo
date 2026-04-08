terraform {
  backend "s3" {
    bucket = "devops-test-tfstate-344302550695"
    key = "prod/terraform.tfstate"
    region = "ap-northeast-1"
    encrypt = true
    use_lockfile = true
  }
}