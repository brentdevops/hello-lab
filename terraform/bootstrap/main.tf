# Creates the S3 bucket that holds the main stack's state.
# This stack itself uses LOCAL state (chicken-and-egg: the bucket can't store its own creation).

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "hello-lab" }
  }
}

data "aws_caller_identity" "me" {}

resource "aws_s3_bucket" "state" {
  bucket        = "hello-lab-tfstate-${data.aws_caller_identity.me.account_id}"
  force_destroy = true # lab only: lets `terraform destroy` delete a non-empty bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket" {
  value = aws_s3_bucket.state.bucket
}
