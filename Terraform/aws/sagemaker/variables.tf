variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "endpoint_name" {
  description = "SageMaker endpoint name"
  type        = string
}

variable "model_name" {
  description = "SageMaker model name"
  type        = string
}

variable "model_data_url" {
  description = "S3 URI for SageMaker model data"
  type        = string
}

variable "execution_role_arn" {
  description = "SageMaker execution IAM role ARN"
  type        = string
}

variable "memory_size_in_mb" {
  description = "Serverless memory size in MB"
  type        = number
}

variable "max_concurrency" {
  description = "Serverless max concurrency"
  type        = number
}
