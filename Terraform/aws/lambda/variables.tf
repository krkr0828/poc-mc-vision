variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "lambda_role_arn" {
  description = "Lambda IAM role ARN"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket containing Lambda deployment package"
  type        = string
}

variable "s3_trigger_bucket" {
  description = "S3 bucket name for Lambda event trigger (image upload bucket)"
  type        = string
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for event notification"
  type        = string
}

variable "s3_key" {
  description = "S3 key for Lambda deployment package"
  type        = string
}

variable "handler" {
  description = "Lambda handler"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
}

variable "sagemaker_endpoint" {
  description = "SageMaker endpoint name"
  type        = string
}

variable "bedrock_model" {
  description = "Bedrock model ID"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}
