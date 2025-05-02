provider "aws" {
  region = var.aws_region
  profile = "personal"
}

# Archive the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../temp_build"
  output_path = "${path.module}/lambda_function.zip"
}

# Create Lambda function
resource "aws_lambda_function" "fastapi_lambda" {
  function_name    = "fastapi-hello-${var.stage}"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "app.handler"
  runtime          = "python3.9"
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout

  role = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      STAGE = var.stage
      LOG_LEVEL = "INFO"
    }
  }

  # Add logging configuration
  logging_config {
    log_format = "JSON"
    log_group  = "/aws/lambda/fastapi-hello-${var.stage}"
    application_log_level = "INFO"
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "fastapi-lambda-role-${var.stage}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

## Create API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = "fastapi-lambda-api-${var.stage}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = var.stage
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  
  integration_uri    = aws_lambda_function.fastapi_lambda.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

# Single catch-all route that handles all paths
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fastapi_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# Output the API URL
output "api_url" {
  description = "API Gateway URL"
  value       = "${aws_apigatewayv2_stage.stage.invoke_url}"
}