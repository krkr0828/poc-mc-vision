variable "function_name" {
  description = "FastAPI Lambda function name"
  type        = string
}

variable "lambda_role_arn" {
  description = "IAM role ARN assumed by the Lambda function"
  type        = string
}

variable "image_uri" {
  description = "ECR image URI for the Lambda container"
  type        = string
}

variable "memory_size" {
  description = "Lambda memory in MB"
  type        = number
  default     = 1024
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 60
}

variable "environment" {
  description = "Environment variables map"
  type        = map(string)
  default     = {}
}

variable "function_url_auth_type" {
  description = "FastAPI Lambda Function URL auth type"
  type        = string
  default     = "NONE"
}

variable "create_function_url" {
  description = "Whether to create a public function URL"
  type        = bool
  default     = true
}

variable "image_command" {
  description = "Optional override command for the container image (e.g., handler)"
  type        = list(string)
  default     = null
}
