output "lambda_role_arn" {
  description = "Lambda IAM role ARN"
  value       = aws_iam_role.lambda.arn
}

output "lambda_role_name" {
  description = "Lambda IAM role name"
  value       = aws_iam_role.lambda.name
}

output "sagemaker_role_arn" {
  description = "SageMaker IAM role ARN"
  value       = aws_iam_role.sagemaker.arn
}

output "sagemaker_role_name" {
  description = "SageMaker IAM role name"
  value       = aws_iam_role.sagemaker.name
}
