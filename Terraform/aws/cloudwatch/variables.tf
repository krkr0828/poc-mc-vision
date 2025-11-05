variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
}
