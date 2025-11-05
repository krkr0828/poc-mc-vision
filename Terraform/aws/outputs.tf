# ====================
# S3 Outputs
# ====================

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = module.s3.bucket_arn
}

# ====================
# Lambda Outputs
# ====================

output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = module.lambda.lambda_arn
}

output "lambda_role_arn" {
  description = "Lambda IAM role ARN"
  value       = module.iam.lambda_role_arn
}

# ====================
# DynamoDB Outputs
# ====================

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = module.dynamodb.table_arn
}

# ====================
# SageMaker Outputs
# ====================

output "sagemaker_endpoint_name" {
  description = "SageMaker endpoint name"
  value       = module.sagemaker.endpoint_name
}

output "sagemaker_endpoint_arn" {
  description = "SageMaker endpoint ARN"
  value       = module.sagemaker.endpoint_arn
}

# ====================
# CloudWatch Outputs
# ====================

output "cloudwatch_log_group_name" {
  description = "CloudWatch Logs group name"
  value       = module.cloudwatch.log_group_name
}

# ====================
# General Outputs
# ====================

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}
