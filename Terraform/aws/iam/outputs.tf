output "lambda_role_arn" {
  description = "Lambda IAM role ARN"
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_name" {
  description = "Lambda IAM role name"
  value       = aws_iam_role.lambda.name
}

output "fastapi_lambda_role_arn" {
  description = "FastAPI Lambda IAM role ARN"
  value       = aws_iam_role.fastapi.arn
}

output "fastapi_lambda_role_name" {
  description = "FastAPI Lambda IAM role name"
  value       = aws_iam_role.fastapi.name
}

output "pipeline_worker_role_arn" {
  description = "Pipeline worker Lambda role ARN"
  value       = aws_iam_role.pipeline_worker.arn
}

output "pipeline_worker_role_name" {
  description = "Pipeline worker Lambda role name"
  value       = aws_iam_role.pipeline_worker.name
}

output "sagemaker_role_arn" {
  description = "SageMaker IAM role ARN"
  value       = aws_iam_role.sagemaker.arn
}

output "sagemaker_role_name" {
  description = "SageMaker IAM role name"
  value       = aws_iam_role.sagemaker.name
}
