# The EC2 node's role. The server assumes it automatically. It needs:
#   - ECR read → pull the app image
#   - SSM core → lets the pipeline (and you) run commands on the node with no SSH and no open port
#
# GitHub's access to AWS (OIDC + roles) lives in terraform/bootstrap, so destroying
# this stack never cuts the pipeline off.

resource "aws_iam_role" "node" {
  name = "hello-lab-node"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_ecr_read" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "node" {
  name = "hello-lab-node"
  role = aws_iam_role.node.name
}
