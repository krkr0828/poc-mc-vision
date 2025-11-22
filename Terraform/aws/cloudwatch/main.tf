# ====================
# CloudWatch Log Groups
# ====================

resource "aws_cloudwatch_log_group" "s3_lambda" {
  name              = "/aws/lambda/${var.s3_lambda_function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "fastapi_lambda" {
  name              = "/aws/lambda/${var.fastapi_lambda_function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "pipeline_worker_lambda" {
  name              = "/aws/lambda/${var.pipeline_worker_lambda_name}"
  retention_in_days = var.log_retention_days
}
