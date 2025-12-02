variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "lambda_role_name" {
  description = "Lambda IAM role name"
  type        = string
}

variable "pipeline_worker_role_name" {
  description = "Pipeline worker Lambda role name"
  type        = string
}

variable "fastapi_role_name" {
  description = "FastAPI Lambda execution role name"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for image uploads"
  type        = string
}

variable "lambda_zip_bucket" {
  description = "S3 bucket name for Lambda deployment packages and SageMaker models"
  type        = string
}

variable "bedrock_model_id" {
  description = "Bedrock model identifier used by Lambda"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "sagemaker_endpoint_name" {
  description = "SageMaker endpoint name for pipeline worker access"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN for SageMaker access"
  type        = string
}
