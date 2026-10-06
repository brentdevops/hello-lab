# One EC2 node running k3s (single-node Kubernetes), in the default VPC.
# No SSH: you reach the server through AWS SSM (see scripts/kubeconfig.sh).

# ---------- network ----------
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "node" {
  name        = "hello-lab-node"
  description = "hello-lab k3s node"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "k8s_api" {
  security_group_id = aws_security_group.node.id
  description       = "kubectl from my IP"
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id = aws_security_group.node.id
  description       = "app NodePort from my IP"
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = var.node_port
  to_port           = var.node_port
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.node.id
  description       = "all outbound (k3s install, ECR pulls, SSM)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- the node ----------
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  ecr_registry = split("/", aws_ecr_repository.app.repository_url)[0]
}

resource "aws_instance" "node" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.node.id]
  iam_instance_profile   = aws_iam_instance_profile.node.name

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    region   = var.region
    registry = local.ecr_registry
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  tags = { Name = "hello-lab-node" }

  lifecycle {
    ignore_changes = [ami] # don't replace the node every time AWS publishes a new AMI
  }
}
