variable "repository_name" {
  description = "Name of the ECR repository for FastAPI images"
  type        = string
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "image_tag_mutability" {
  description = "Tag mutability setting (IMMUTABLE prevents accidental overwrites)"
  type        = string
  default     = "IMMUTABLE"
}
