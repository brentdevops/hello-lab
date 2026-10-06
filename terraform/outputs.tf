# The pipeline reads these with `terraform output -raw <name>`.

output "public_ip" {
  value = aws_instance.node.public_ip
}

output "instance_id" {
  value = aws_instance.node.id
}

output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}

output "app_url" {
  value = "http://${aws_instance.node.public_ip}:${var.node_port}"
}
