# OPS-262: the notes app.
#   browser -> API Gateway (public URL) -> Lambda (inside the VPC) -> RDS (private, inside the VPC)
#   the Lambda gets the DB password from Secrets Manager; everything it prints -> CloudWatch Logs

# ---------- the network: AWS's default VPC, 2 of its subnets ----------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "app" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b"]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# ---------- firewalls (security groups) ----------
# the Lambda's firewall: it may call out to anything
resource "aws_security_group" "lambda" {
  name        = "notes-lambda"
  description = "notes app Lambda"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_egress_rule" "lambda_out" {
  security_group_id = aws_security_group.lambda.id
  description       = "all outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# the database's firewall: only the Lambda, only on 5432
resource "aws_security_group" "db" {
  name        = "notes-db"
  description = "notes app RDS"
  vpc_id      = data.aws_vpc.default.id
}


# ---------- Secrets Manager, reachable from inside the VPC ----------
# The Lambda has no internet access inside the VPC, so it reaches Secrets Manager through this private door.
resource "aws_security_group" "secrets_endpoint" {
  name        = "notes-secrets-endpoint"
  description = "Secrets Manager endpoint for the notes app"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_from_lambda" {
  security_group_id            = aws_security_group.secrets_endpoint.id
  description                  = "https from the Lambda"
  referenced_security_group_id = aws_security_group.lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_endpoint" "secrets" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.app.ids
  security_group_ids  = [aws_security_group.secrets_endpoint.id]
  private_dns_enabled = true
}

# ---------- the database (RDS) ----------
resource "aws_db_instance" "notes" {
  identifier     = "notes-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  username                    = "postgres"
  manage_master_user_password = true

  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
}

# ---------- the Lambda's permission slip (IAM role) ----------
resource "aws_iam_role" "lambda" {
  name = "notes-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# allow: write logs + plug into the VPC
resource "aws_iam_role_policy_attachment" "vpc_and_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# allow: read the DB password (and only that secret)
resource "aws_iam_role_policy" "read_db_secret" {
  name = "read-db-secret"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_db_instance.notes.master_user_secret[0].secret_arn
    }]
  })
}

# ---------- the Lambda (src/handler.py + the Postgres library) ----------
data "archive_file" "code" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/.build/notes.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/notes-app"
  retention_in_days = 1
}

resource "aws_lambda_function" "notes" {
  function_name    = "notes-app"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.code.output_path
  source_code_hash = data.archive_file.code.output_base64sha256
  timeout          = 15
  memory_size      = 256

  vpc_config {
    subnet_ids         = data.aws_subnets.app.ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_HOST       = aws_db_instance.notes.address
      DB_SECRET_ARN = aws_db_instance.notes.master_user_secret[0].secret_arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda, aws_iam_role_policy_attachment.vpc_and_logs]
}

# ---------- API Gateway: the public URL ----------
resource "aws_apigatewayv2_api" "http" {
  name          = "notes-app"
  protocol_type = "HTTP"
  target        = aws_lambda_function.notes.arn
}

# allow: API Gateway may run the Lambda
resource "aws_lambda_permission" "api" {
  statement_id  = "allow-api-gateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notes.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*"
}

output "url" {
  value = aws_apigatewayv2_api.http.api_endpoint
}
