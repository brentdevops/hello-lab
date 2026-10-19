variable "name" {
  type = string
}

variable "env" {
  type = string
}

resource "aws_s3_bucket" "this" {
  bucket = "brent-tf-lab-${var.name}-${var.env}-604834692038"

  tags = {
    Env = var.env
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.this.bucket
}
