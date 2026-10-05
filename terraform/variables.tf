variable "region" {
  type    = string
  default = "us-east-1"
}

variable "my_ip_cidr" {
  description = "Your public IP as a /32, e.g. 203.0.113.7/32. Only this IP can reach SSH, the k8s API, and the app."
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0)) && endswith(var.my_ip_cidr, "/32")
    error_message = "my_ip_cidr must be a single IP in CIDR form, ending in /32."
  }
}

variable "github_repo" {
  description = "owner/name of the GitHub repo allowed to deploy, e.g. brent/hello-lab"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.small" # 2 GB RAM. t3.micro (1 GB) is too small for k3s + app.
}

variable "alert_email" {
  description = "Optional. If set, CloudWatch alarms email this address (you must confirm the SNS email)."
  type        = string
  default     = ""
}

variable "node_port" {
  type    = number
  default = 30080
}
