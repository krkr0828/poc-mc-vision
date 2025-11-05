# ====================
# DynamoDB Table
# ====================

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"

  attribute {
    name = "request_id"
    type = "S"
  }

  # TTL設定
  ttl {
    attribute_name = "expire_at"
    enabled        = true
  }

  # Point-in-time recovery (任意)
  point_in_time_recovery {
    enabled = false
  }

  # Server-side encryption (at-rest)
  server_side_encryption {
    enabled = true
  }
}
