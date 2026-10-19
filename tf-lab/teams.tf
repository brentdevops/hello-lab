variable "teams" {
  type    = list(string)
  default = ["payments", "auth"]
}

resource "aws_s3_bucket" "team" {
  for_each = toset(var.teams)
  bucket   = "brent-tf-lab-${each.key}-604834692038"
}
