# FastAPI Lambda API with Terraform

This project demonstrates how to deploy a FastAPI application to AWS Lambda using Terraform. It includes a complete infrastructure setup with API Gateway, Lambda function, and necessary IAM roles.

## Project Structure

```
.
├── fastapi_app/
│   ├── app.py              # FastAPI application
│   └── requirements.txt    # Python dependencies
├── terraform/
│   ├── main.tf            # Main Terraform configuration
│   ├── variables.tf       # Variable definitions
│   └── config/
│       └── dev.tfvars     # Development environment variables
├── temp_build/            # Temporary build directory for Lambda package
└── local_deploy.sh        # Deployment script
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed
- Python 3.9 or later
- pip (Python package manager)

## Infrastructure Components

### 1. Lambda Function (`aws_lambda_function`)

```hcl
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

  logging_config {
    log_format = "JSON"
    log_group  = "/aws/lambda/fastapi-hello-${var.stage}"
    application_log_level = "INFO"
  }
}
```

Key components:

- `function_name`: Unique name for the Lambda function
- `handler`: Points to the Mangum handler in app.py
- `runtime`: Python 3.9 runtime
- `environment`: Environment variables for the function
- `logging_config`: JSON-formatted logging configuration

### 2. IAM Role and Permissions

```hcl
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

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
```

This configuration:

- Creates an IAM role for the Lambda function
- Attaches the basic Lambda execution policy for CloudWatch Logs access

### 3. API Gateway

```hcl
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

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}
```

Key components:

- HTTP API Gateway (v2)
- Auto-deploying stage
- Lambda integration with proxy integration
- Catch-all route for all paths

### 4. Lambda Permission

```hcl
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fastapi_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
```

This allows API Gateway to invoke the Lambda function.

## Deployment

1. **Manual Deployment**:

```bash
./local_deploy.sh
```

2. **Automated Deployment** (no prompts):

```bash
./local_deploy.sh --auto-approve
```

3. **Deploy and Show Logs**:

```bash
./local_deploy.sh --auto-approve --show-logs
```

## FastAPI Application

The FastAPI application uses Mangum to handle AWS Lambda integration:

```python
from fastapi import FastAPI, Request
from mangum import Mangum
import logging
import os

# Configure logging
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI()

@app.get("/")
async def read_root(request: Request):
    logger.info(f"Root endpoint called. Path: {request.url.path}, Method: {request.method}")
    return {"Hello": "World"}

@app.get("/hello")
async def read_hello(request: Request):
    logger.info(f"Hello endpoint called. Path: {request.url.path}, Method: {request.method}")
    return {"message": "Hello from FastAPI on AWS Lambda!"}

handler = Mangum(app, lifespan="off", api_gateway_base_path=f"/{STAGE}")
```

## Environment Variables

The project uses the following environment variables:

- `STAGE`: Deployment stage (e.g., "dev", "prod")
- `LOG_LEVEL`: Logging level for the application
- `AWS_REGION`: AWS region for deployment

## Monitoring and Logging

Logs are available in CloudWatch Logs under the log group:

```
/aws/lambda/fastapi-hello-${STAGE}
```

View logs using:

```bash
./local_deploy.sh --show-logs
```

## Cleanup

To destroy the infrastructure:

```bash
cd terraform
terraform destroy
```
