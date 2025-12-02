variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
}

variable "project_name" {
  description = "Project name prefix used for log groups and alarms"
  type        = string
}

variable "s3_lambda_function_name" {
  description = "S3 ingestion Lambda function name"
  type        = string
}

variable "fastapi_lambda_function_name" {
  description = "FastAPI Lambda function name"
  type        = string
}

variable "pipeline_worker_lambda_name" {
  description = "Pipeline worker Lambda function name"
  type        = string
}

variable "state_machine_arn" {
  description = "ARN of the Step Functions state machine to monitor"
  type        = string
}

variable "alarm_topic_arn" {
  description = "SNS Topic ARN to notify on alarm"
  type        = string
}

variable "latency_threshold_ms" {
  description = "P95 duration threshold for Lambda alarms"
  type        = number
  default     = 3000
}

variable "sagemaker_endpoint_name" {
  description = "SageMaker endpoint name for monitoring"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for monitoring"
  type        = string
}
