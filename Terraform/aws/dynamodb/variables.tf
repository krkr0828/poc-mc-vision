variable "table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "ttl_days" {
  description = "TTL expiration in days (used for documentation only - actual TTL value is set by application)"
  type        = number
}
