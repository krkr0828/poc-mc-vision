output "s3_lambda_log_group_name" {
  description = "CloudWatch Logs group name for the ingestion Lambda"
  value       = aws_cloudwatch_log_group.s3_lambda.name
}

output "fastapi_lambda_log_group_name" {
  description = "CloudWatch Logs group name for the FastAPI Lambda"
  value       = aws_cloudwatch_log_group.fastapi_lambda.name
}

output "pipeline_worker_log_group_name" {
  description = "CloudWatch Logs group name for the pipeline worker Lambda"
  value       = aws_cloudwatch_log_group.pipeline_worker_lambda.name
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.operations.dashboard_name
}

output "dashboard_arn" {
  description = "CloudWatch dashboard ARN"
  value       = aws_cloudwatch_dashboard.operations.dashboard_arn
}
