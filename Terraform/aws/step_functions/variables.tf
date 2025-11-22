variable "project_name" {
  description = "Project prefix used for naming the Step Functions state machine"
  type        = string
}

variable "state_machine_name" {
  description = "Step Functions state machine name"
  type        = string
  default     = "poc-mc-vision-pipeline"
}

variable "log_retention_days" {
  description = "Retention period for Step Functions log group"
  type        = number
  default     = 7
}

variable "dynamodb_table_name" {
  description = "DynamoDB table storing pipeline results"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS Topic ARN used for pipeline notifications"
  type        = string
}

variable "lambda_worker_arn" {
  description = "Pipeline worker Lambda ARN used for model invocations"
  type        = string
}
