resource "aws_s3_bucket" "app_logs" {
  bucket = "brent-tf-lab-logs-604834692038"

  tags = {
    Owner = "brent"
    Env   = "lab"
  }
}

moved {
  from = aws_s3_bucket.logs
  to   = aws_s3_bucket.app_logs
}
