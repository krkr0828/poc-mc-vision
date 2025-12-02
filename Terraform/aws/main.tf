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

  project_name              = var.project_name
  lambda_role_name          = var.lambda_role_name
  fastapi_role_name         = var.fastapi_lambda_role_name
  pipeline_worker_role_name = var.pipeline_worker_role_name
  s3_bucket_name            = var.s3_bucket_name
  lambda_zip_bucket         = var.lambda_zip_bucket
  bedrock_model_id          = var.bedrock_model_id
  dynamodb_table_name       = var.dynamodb_table_name
  sagemaker_endpoint_name   = var.sagemaker_endpoint_name
  ecr_repository_arn        = module.ecr.repository_arn
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

module "sns" {
  source = "./sns"

  project_name = var.project_name
  alert_email  = var.alert_email
}

module "ecr" {
  source = "./ecr"

  repository_name = var.fastapi_repository_name
}

module "cloudwatch" {
  source = "./cloudwatch"

  project_name                 = var.project_name
  s3_lambda_function_name      = var.lambda_function_name
  fastapi_lambda_function_name = module.lambda_fastapi.function_name
  pipeline_worker_lambda_name  = module.lambda_pipeline_worker.function_name
  state_machine_arn            = module.step_functions.state_machine_arn
  alarm_topic_arn              = module.sns.topic_arn
  log_retention_days           = var.log_retention_days
  sagemaker_endpoint_name      = module.sagemaker.endpoint_name
  dynamodb_table_name          = module.dynamodb.table_name
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

module "step_functions" {
  source = "./step_functions"

  project_name        = var.project_name
  state_machine_name  = var.state_machine_name
  dynamodb_table_name = var.dynamodb_table_name
  sns_topic_arn       = module.sns.topic_arn
  log_retention_days  = 7
  lambda_worker_arn   = module.lambda_pipeline_worker.function_arn
}

module "lambda_fastapi" {
  source = "./lambda_fastapi"

  function_name          = var.fastapi_lambda_function_name
  lambda_role_arn        = module.iam.fastapi_lambda_role_arn
  memory_size            = var.fastapi_lambda_memory_size
  timeout                = var.fastapi_lambda_timeout
  function_url_auth_type = var.fastapi_function_url_auth_type
  image_uri              = "${module.ecr.repository_url}:${var.fastapi_image_tag}"
  environment = {
    S3_UPLOAD_BUCKET             = var.s3_bucket_name
    DDB_TABLE                    = var.dynamodb_table_name
    SAGEMAKER_ENDPOINT_NAME      = var.sagemaker_endpoint_name
    BEDROCK_MODEL_ID             = var.bedrock_model_id
    STEP_FUNCTION_ARN            = module.step_functions.state_machine_arn
    ALERT_SNS_TOPIC_ARN          = module.sns.topic_arn
    AZURE_OPENAI_ENDPOINT        = var.azure_openai_endpoint
    AZURE_OPENAI_API_KEY         = var.azure_openai_api_key
    AZURE_OPENAI_DEPLOYMENT_MINI = var.azure_openai_deployment
    AZURE_OPENAI_API_VERSION     = var.azure_openai_api_version
    USE_AZURE                    = "1"
    USE_SAGEMAKER                = "1"
    USE_BEDROCK                  = "1"
    USE_REAL                     = "1"
    USE_GUARDRAILS               = var.use_guardrails ? "1" : "0"
    BEDROCK_GUARDRAIL_ID         = var.bedrock_guardrail_id
    BEDROCK_GUARDRAIL_VERSION    = var.bedrock_guardrail_version
  }

  depends_on = [
    module.step_functions,
    module.ecr
  ]
}

module "lambda_pipeline_worker" {
  source = "./lambda_fastapi"

  function_name          = var.pipeline_worker_function_name
  lambda_role_arn        = module.iam.pipeline_worker_role_arn
  memory_size            = var.pipeline_worker_memory_size
  timeout                = var.pipeline_worker_timeout
  image_uri              = "${module.ecr.repository_url}:${var.fastapi_image_tag}"
  create_function_url    = false
  function_url_auth_type = "NONE"
  image_command          = ["main.pipeline_handler"]
  environment = {
    S3_UPLOAD_BUCKET             = var.s3_bucket_name
    SAGEMAKER_ENDPOINT_NAME      = var.sagemaker_endpoint_name
    BEDROCK_MODEL_ID             = var.bedrock_model_id
    USE_SAGEMAKER                = "1"
    USE_BEDROCK                  = "1"
    USE_AZURE                    = "1"
    AZURE_OPENAI_ENDPOINT        = var.azure_openai_endpoint
    AZURE_OPENAI_API_KEY         = var.azure_openai_api_key
    AZURE_OPENAI_DEPLOYMENT_MINI = var.azure_openai_deployment
    AZURE_OPENAI_API_VERSION     = var.azure_openai_api_version
    USE_REAL                     = "1"
    USE_GUARDRAILS               = var.use_guardrails ? "1" : "0"
    BEDROCK_GUARDRAIL_ID         = var.bedrock_guardrail_id
    BEDROCK_GUARDRAIL_VERSION    = var.bedrock_guardrail_version
  }

  depends_on = [
    module.ecr
  ]
}
