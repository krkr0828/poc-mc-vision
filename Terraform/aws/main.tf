terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}

# Data source: AWS Account ID
data "aws_caller_identity" "current" {}

# Modules
module "iam" {
  source = "./iam"

  project_name        = var.project_name
  lambda_role_name    = var.lambda_role_name
  s3_bucket_name      = var.s3_bucket_name
  lambda_zip_bucket   = var.lambda_zip_bucket
  bedrock_model_id    = var.bedrock_model_id
  dynamodb_table_name = var.dynamodb_table_name
}

module "s3" {
  source = "./s3"

  bucket_name = var.s3_bucket_name
}

module "dynamodb" {
  source = "./dynamodb"

  table_name = var.dynamodb_table_name
  ttl_days   = var.ttl_days
}

module "cloudwatch" {
  source = "./cloudwatch"

  lambda_function_name = var.lambda_function_name
  log_retention_days   = var.log_retention_days
}

module "lambda" {
  source = "./lambda"

  function_name       = var.lambda_function_name
  lambda_role_arn     = module.iam.lambda_role_arn
  s3_bucket           = var.lambda_zip_bucket
  s3_trigger_bucket   = var.s3_bucket_name
  s3_bucket_arn       = module.s3.bucket_arn
  s3_key              = var.lambda_zip_key
  handler             = var.lambda_handler
  runtime             = var.lambda_runtime
  timeout             = var.lambda_timeout
  memory_size         = var.lambda_memory_size
  sagemaker_endpoint  = var.sagemaker_endpoint_name
  bedrock_model       = var.bedrock_model_id
  dynamodb_table_name = var.dynamodb_table_name

  depends_on = [
    module.cloudwatch,
    module.s3
  ]
}

module "sagemaker" {
  source = "./sagemaker"

  project_name       = var.project_name
  endpoint_name      = var.sagemaker_endpoint_name
  model_name         = var.sagemaker_model_name
  model_data_url     = var.sagemaker_model_data_url
  memory_size_in_mb  = var.sagemaker_memory_size
  max_concurrency    = var.sagemaker_max_concurrency
  execution_role_arn = module.iam.sagemaker_role_arn
}
