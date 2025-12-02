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

variable "fastapi_lambda_function_name" {
  description = "FastAPI Lambda function name"
  type        = string
  default     = "poc-mc-vision-fastapi"
}

variable "pipeline_worker_function_name" {
  description = "Lambda function name for Step Functions worker"
  type        = string
  default     = "poc-mc-vision-pipeline-worker"
}

variable "lambda_role_name" {
  description = "IAM role name for Lambda"
  type        = string
  default     = "poc-mc-vision-lambda-role"
}

variable "fastapi_lambda_role_name" {
  description = "IAM role for the FastAPI Lambda container"
  type        = string
  default     = "poc-mc-vision-fastapi-role"
}

variable "pipeline_worker_role_name" {
  description = "IAM role for the pipeline worker Lambda"
  type        = string
  default     = "poc-mc-vision-pipeline-role"
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

variable "fastapi_lambda_timeout" {
  description = "FastAPI Lambda timeout in seconds"
  type        = number
  default     = 60
}

variable "pipeline_worker_timeout" {
  description = "Pipeline worker Lambda timeout in seconds"
  type        = number
  default     = 120
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "fastapi_lambda_memory_size" {
  description = "FastAPI Lambda memory size in MB"
  type        = number
  default     = 1024
}

variable "pipeline_worker_memory_size" {
  description = "Pipeline worker Lambda memory size in MB"
  type        = number
  default     = 1024
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
  default     = 7
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
# FastAPI Container / ECR
# ====================

variable "fastapi_repository_name" {
  description = "ECR repository name for FastAPI container image"
  type        = string
  default     = "poc-mc-vision-fastapi"
}

variable "fastapi_image_tag" {
  description = "Image tag pushed to ECR (used for Lambda image URI)"
  type        = string
  default     = "latest"
}

variable "fastapi_function_url_auth_type" {
  description = "Authorization type for the FastAPI Lambda Function URL"
  type        = string
  default     = "NONE"
}

# ====================
# Azure OpenAI Settings
# ====================

variable "azure_openai_endpoint" {
  description = "Azure OpenAI endpoint base URL"
  type        = string
  default     = "https://aoai-poc-vision-eastus2.openai.azure.com"
}

variable "azure_openai_api_key" {
  description = "Azure OpenAI API key (sensitive)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "azure_openai_deployment" {
  description = "Azure OpenAI deployment name for GPT-4o mini"
  type        = string
  default     = "gpt4omini-poc"
}

variable "azure_openai_api_version" {
  description = "Azure OpenAI API version"
  type        = string
  default     = "2024-10-21"
}

# ====================
# CloudWatch Settings
# ====================

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Invalid retention period. Must be a valid CloudWatch Logs retention value."
  }
}

variable "alert_email" {
  description = "Alert destination email address for SNS subscriptions"
  type        = string
  default     = "krkr_ajm@icloud.com"
}

# ====================
# Step Functions
# ====================

variable "state_machine_name" {
  description = "Name of the Step Functions state machine"
  type        = string
  default     = "poc-mc-vision-pipeline"
}

# ====================
# Guardrails
# ====================

variable "use_guardrails" {
  description = "Enable Bedrock Guardrails usage"
  type        = bool
  default     = false
}

variable "bedrock_guardrail_id" {
  description = "Guardrail identifier"
  type        = string
  default     = ""
}

variable "bedrock_guardrail_version" {
  description = "Guardrail version"
  type        = string
  default     = ""
}
