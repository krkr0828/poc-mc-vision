# CloudWatch Dashboard for Operations Monitoring

data "aws_region" "current" {}

locals {
  dashboard_params = {
    region               = jsonencode(data.aws_region.current.name)
    state_machine_arn    = jsonencode(var.state_machine_arn)
    sagemaker_endpoint   = jsonencode(var.sagemaker_endpoint_name)
    pipeline_worker_name = jsonencode(var.pipeline_worker_lambda_name)
    fastapi_lambda_name  = jsonencode(var.fastapi_lambda_function_name)
    dynamodb_table_name  = jsonencode(var.dynamodb_table_name)
  }
}

resource "aws_cloudwatch_dashboard" "operations" {
  dashboard_name = "${var.project_name}-operations"
  dashboard_body = templatefile("${path.module}/dashboard.json.tpl", local.dashboard_params)
}
