# ====================
# General Settings
# ====================

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "poc-mc-vision"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

# ====================
# S3 Settings
# ====================

variable "s3_bucket_name" {
  description = "S3 bucket name for image uploads"
  type        = string
  default     = "poc-mc-vision-upload"
}

variable "lambda_zip_bucket" {
  description = "S3 bucket name for Lambda deployment packages and SageMaker models"
  type        = string
  default     = "poc-mc-vision-zip"
}

# ====================
# Lambda Settings
# ====================

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
  default     = "poc-mc-vision-handler"
}

variable "lambda_role_name" {
  description = "IAM role name for Lambda"
  type        = string
  default     = "poc-mc-vision-lambda-role"
}

variable "lambda_zip_key" {
  description = "S3 key for Lambda deployment package"
  type        = string
  default     = "poc-mc-vision-handler.zip"
}

variable "lambda_handler" {
  description = "Lambda function handler"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.12"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 60
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

# ====================
# DynamoDB Settings
# ====================

variable "dynamodb_table_name" {
  description = "DynamoDB table name for storing inference results"
  type        = string
  default     = "poc-mc-vision-table"
}

variable "ttl_days" {
  description = "DynamoDB TTL expiration in days"
  type        = number
  default     = 1
}

# ====================
# SageMaker Settings
# ====================

variable "sagemaker_endpoint_name" {
  description = "SageMaker endpoint name"
  type        = string
  default     = "poc-mc-vision-sm"
}

variable "sagemaker_model_name" {
  description = "SageMaker model name"
  type        = string
  default     = "poc-mc-vision-sm-model"
}

variable "sagemaker_model_data_url" {
  description = "S3 URI for SageMaker model data"
  type        = string
  default     = "s3://poc-mc-vision-zip/model_torchscript.tar.gz"
}

variable "sagemaker_memory_size" {
  description = "SageMaker serverless memory size in MB"
  type        = number
  default     = 1024
  validation {
    condition     = contains([1024, 2048, 3072, 4096, 5120, 6144], var.sagemaker_memory_size)
    error_message = "SageMaker serverless memory must be 1024, 2048, 3072, 4096, 5120, or 6144 MB."
  }
}

variable "sagemaker_max_concurrency" {
  description = "SageMaker serverless max concurrency"
  type        = number
  default     = 1
  validation {
    condition     = var.sagemaker_max_concurrency >= 1 && var.sagemaker_max_concurrency <= 200
    error_message = "Max concurrency must be between 1 and 200."
  }
}

# ====================
# Bedrock Settings
# ====================

variable "bedrock_model_id" {
  description = "Bedrock model identifier"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

# ====================
# CloudWatch Settings
# ====================

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 1
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Invalid retention period. Must be a valid CloudWatch Logs retention value."
  }
}
# CI/CD test
