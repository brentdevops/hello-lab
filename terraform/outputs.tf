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

output "ssh" {
  value = "ssh -i hello-lab.pem ec2-user@${aws_instance.node.public_ip}"
}

output "get_kubeconfig" {
  description = "Run from the terraform/ folder. Copies the cluster's kubeconfig to your laptop."
  value       = "ssh -i hello-lab.pem ec2-user@${aws_instance.node.public_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/${aws_instance.node.public_ip}/' > ../kubeconfig"
}

output "github_role_arn" {
  value = aws_iam_role.github.arn
}
