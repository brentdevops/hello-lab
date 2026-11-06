# OPS-250: a tiny upload API.
#   browser -> API Gateway (public URL) -> Lambda (handler.py) -> S3 (saves a file)
#   everything the Lambda prints -> CloudWatch Logs

data "aws_caller_identity" "me" {}

# ---------- S3: where uploads are saved ----------
resource "aws_s3_bucket" "uploads" {
  bucket        = "hello-lab-uploads-${data.aws_caller_identity.me.account_id}"
  force_destroy = true # lab only: destroy works even with files inside
}

# ---------- IAM: the Lambda's permission slip ----------
resource "aws_iam_role" "lambda" {
  name = "hello-lab-upload-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# allow: write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# allow: save files into the uploads bucket (break #1 removes this)
resource "aws_iam_role_policy" "s3_write" {
  name = "write-uploads"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.uploads.arn}/*"
    }]
  })
}

# ---------- Lambda: the Python code ----------
data "archive_file" "code" {
  type        = "zip"
  source_file = "${path.module}/handler.py"
  output_path = "${path.module}/.build/handler.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/hello-lab-upload"
  retention_in_days = 1
}

resource "aws_lambda_function" "upload" {
  function_name    = "hello-lab-upload"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.code.output_path
  source_code_hash = data.archive_file.code.output_base64sha256
  timeout          = 3

  environment {
    variables = {
      BUCKET        = aws_s3_bucket.uploads.bucket
      DELAY_SECONDS = "0"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda, aws_iam_role_policy_attachment.logs]
}

# ---------- API Gateway: the public URL ----------
resource "aws_apigatewayv2_api" "http" {
  name          = "hello-lab-upload"
  protocol_type = "HTTP"
  target        = aws_lambda_function.upload.arn
}

# allow: API Gateway may run the Lambda
resource "aws_lambda_permission" "api" {
  statement_id  = "allow-api-gateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*"
}

output "url" {
  value = aws_apigatewayv2_api.http.api_endpoint
}

output "bucket" {
  value = aws_s3_bucket.uploads.bucket
}
