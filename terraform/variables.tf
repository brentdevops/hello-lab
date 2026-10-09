variable "region" {
  type    = string
  default = "us-east-1"
}

variable "my_ip_cidr" {
  description = "Who can reach the k8s API and the app. 0.0.0.0/0 = everyone (lab: hotspot IP changes). In CI it comes from the GitHub variable MY_IP_CIDR."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0))
    error_message = "my_ip_cidr must be a valid CIDR, e.g. 0.0.0.0/0 or 1.2.3.4/32."
  }
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
