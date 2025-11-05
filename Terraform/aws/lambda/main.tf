# ====================
# Lambda Function
# ====================

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = var.lambda_role_arn

  # S3からデプロイパッケージを取得
  s3_bucket = var.s3_bucket
  s3_key    = var.s3_key

  handler     = var.handler
  runtime     = var.runtime
  timeout     = var.timeout
  memory_size = var.memory_size

  environment {
    variables = {
      SAGEMAKER_ENDPOINT = var.sagemaker_endpoint
      BEDROCK_MODEL      = var.bedrock_model
      TABLE_NAME         = var.dynamodb_table_name
    }
  }

  # Reserved concurrent executions (オプション: 同時実行数制限)
  # reserved_concurrent_executions = 10
}

# ====================
# S3 Event Notification
# ====================

# Lambda permission to allow S3 invocation
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.s3_bucket_arn
}

# S3 Bucket Notification
resource "aws_s3_bucket_notification" "lambda_trigger" {
  bucket = var.s3_trigger_bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
