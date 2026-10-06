variable "region" {
  type    = string
  default = "us-east-1"
}

variable "my_ip_cidr" {
  description = "Your public IP as a /32. Only this IP can reach the k8s API and the app. In CI it comes from the GitHub variable MY_IP_CIDR."
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0)) && endswith(var.my_ip_cidr, "/32")
    error_message = "my_ip_cidr must be a single IP in CIDR form, ending in /32."
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
