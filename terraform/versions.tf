terraform {
  required_version = ">= 1.10" # needed for S3-native state locking (use_lockfile)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Where Terraform keeps its list of what it created (the state file).
  # The bucket is created by terraform/bootstrap.
  backend "s3" {
    bucket       = "hello-lab-tfstate-604834692038"
    key          = "hello-lab/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # lock file lives in S3 next to the state; no DynamoDB table
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "hello-lab" }
  }
}
