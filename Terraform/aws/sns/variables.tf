variable "project_name" {
  description = "Project prefix used for naming the SNS topic"
  type        = string
}

variable "alert_email" {
  description = "Email address to subscribe to the alert topic. Leave blank to skip subscription."
  type        = string
  default     = ""
}
