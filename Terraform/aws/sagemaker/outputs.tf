output "endpoint_name" {
  description = "SageMaker endpoint name"
  value       = aws_sagemaker_endpoint.this.name
}

output "endpoint_arn" {
  description = "SageMaker endpoint ARN"
  value       = aws_sagemaker_endpoint.this.arn
}

output "model_name" {
  description = "SageMaker model name"
  value       = aws_sagemaker_model.this.name
}

output "endpoint_config_name" {
  description = "SageMaker endpoint configuration name"
  value       = aws_sagemaker_endpoint_configuration.this.name
}
