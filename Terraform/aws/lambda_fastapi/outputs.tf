output "function_arn" {
  description = "FastAPI Lambda function ARN"
  value       = aws_lambda_function.fastapi.arn
}

output "function_name" {
  description = "FastAPI Lambda function name"
  value       = aws_lambda_function.fastapi.function_name
}

output "function_url" {
  description = "Public Function URL for FastAPI"
  value       = try(aws_lambda_function_url.fastapi[0].function_url, null)
}
