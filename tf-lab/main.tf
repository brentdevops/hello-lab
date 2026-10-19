resource "aws_s3_bucket" "logs" {
  bucket = "brent-tf-lab-logs-604834692038"

  tags = {
    Owner = "brent"
    Env   = "lab"
  }
}
