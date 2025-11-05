variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "lambda_role_name" {
  description = "Lambda IAM role name"
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
