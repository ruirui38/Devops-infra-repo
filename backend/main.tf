#S3を作成
resource "aws_s3_bucket" "remote_s3" {
  bucket = "devops-test-tfstate-20260409"
}

resource "aws_s3_bucket_versioning" "remote_s3_versioning" {
   bucket = aws_s3_bucket.remote_s3.id
  versioning_configuration {
    status = "Enabled"
  }
}