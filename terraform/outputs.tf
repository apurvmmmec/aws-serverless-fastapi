output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.fastapi_lambda.arn
}

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.fastapi_lambda.function_name
}

# output "api_url" {
#   description = "URL of the API Gateway endpoint"
#   value       = aws_apigatewayv2_stage.stage.invoke_url
# }

# output "hello_endpoint" {
#   description = "URL of the hello endpoint"
#   value       = "${aws_apigatewayv2_stage.stage.invoke_url}/hello"
# }