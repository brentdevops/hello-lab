# BOOTSTRAP: the permanent foundation. Run ONCE from your Mac, leave it up.
#   cd terraform/bootstrap && terraform apply
#
# It holds the things the pipeline needs BEFORE it can build anything:
#   1. the S3 bucket for Terraform's state (its list of what exists)
#   2. GitHub's way into AWS (OIDC) + 2 roles the pipeline logs in as
# Cost: $0 while idle (IAM is free, an S3 bucket with one small file is ~free).
#
# This stack uses LOCAL state: the bucket can't store the record of its own creation.

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

variable "github_repo" {
  description = "owner/name of the GitHub repo whose pipeline may use AWS"
  type        = string
  default     = "brentdevops/hello-lab"
}

# GitHub's OIDC badge ("sub") now carries permanent IDs: owner@<id>/repo@<id>.
# Names can be reused by someone else after a delete; IDs never are.
# Found via CloudTrail: repo:brentdevops@224695436/hello-lab@1406194643:pull_request
variable "github_repo_with_ids" {
  type    = string
  default = "brentdevops@224695436/hello-lab@1406194643"
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "hello-lab" }
  }
}

data "aws_caller_identity" "me" {}

# ============ 1. state bucket ============

resource "aws_s3_bucket" "state" {
  bucket        = "hello-lab-tfstate-${data.aws_caller_identity.me.account_id}"
  force_destroy = true # lab only: lets `terraform destroy` delete a non-empty bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled" # every state write is kept → you can roll back a corrupted state
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============ 2. GitHub → AWS (OIDC) ============
# GitHub signs a token: "I am a workflow in repo X, on branch/event Y".
# AWS checks the signature, checks the role's conditions, hands back temporary creds (~1h).
# No AWS password is ever stored in GitHub.

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Who may assume a role = the "sub" (subject) claim in GitHub's token.
#   push/manual run on main → repo:OWNER@ID/REPO@ID:ref:refs/heads/main
#   pull request            → repo:OWNER@ID/REPO@ID:pull_request
locals {
  oidc_aud = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
}

# --- Role A: PLAN (pull requests). Can LOOK at AWS, can't change anything. ---
resource "aws_iam_role" "plan" {
  name = "hello-lab-gha-plan"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = merge(local.oidc_aud, {
          # a list = "any of these". Accept the ID format GitHub sends now, and the old names-only one.
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_repo_with_ids}:pull_request",
            "repo:${var.github_repo}:pull_request",
          ]
        })
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# --- Role B: DEPLOY (main branch only). Can change AWS. ---
resource "aws_iam_role" "deploy" {
  name = "hello-lab-gha-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = merge(local.oidc_aud, {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_repo_with_ids}:ref:refs/heads/main",
            "repo:${var.github_repo}:ref:refs/heads/main",
          ]
        })
      }
    }]
  })
}

# LAB SHORTCUT: full admin. Terraform creates IAM roles, EC2, ECR, alarms... so it needs a lot.
# At work this would be a custom policy listing only the services the stack uses,
# often with a permissions boundary so the pipeline can't grant itself more power.
resource "aws_iam_role_policy_attachment" "deploy_admin" {
  role       = aws_iam_role.deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ============ outputs: copy these into GitHub repo variables ============

output "bucket" {
  value = aws_s3_bucket.state.bucket
}

output "AWS_PLAN_ROLE_ARN" {
  value = aws_iam_role.plan.arn
}

output "AWS_DEPLOY_ROLE_ARN" {
  value = aws_iam_role.deploy.arn
}
