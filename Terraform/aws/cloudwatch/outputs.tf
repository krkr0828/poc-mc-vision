output "log_group_name" {
  description = "CloudWatch Logs group name"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "log_group_arn" {
  description = "CloudWatch Logs group ARN"
  value       = aws_cloudwatch_log_group.lambda.arn
}
