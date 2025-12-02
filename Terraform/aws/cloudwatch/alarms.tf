locals {
  common_lambda_alarm = {
    namespace          = "AWS/Lambda"
    period             = 60
    evaluation_periods = 1
    treat_missing_data = "notBreaching"
    actions_enabled    = true
  }
}

resource "aws_cloudwatch_metric_alarm" "fastapi_errors" {
  alarm_name          = "${var.project_name}-fastapi-errors"
  alarm_description   = "FastAPI Lambda reports any error within 1 minute"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  metric_name         = "Errors"
  namespace           = local.common_lambda_alarm.namespace
  statistic           = "Sum"
  threshold           = 1
  period              = local.common_lambda_alarm.period
  evaluation_periods  = local.common_lambda_alarm.evaluation_periods
  treat_missing_data  = local.common_lambda_alarm.treat_missing_data
  actions_enabled     = local.common_lambda_alarm.actions_enabled
  alarm_actions       = [var.alarm_topic_arn]
  dimensions = {
    FunctionName = var.fastapi_lambda_function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "fastapi_duration" {
  alarm_name          = "${var.project_name}-fastapi-duration"
  alarm_description   = "FastAPI Lambda P95 duration exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  metric_name         = "Duration"
  namespace           = local.common_lambda_alarm.namespace
  extended_statistic  = "p95"
  threshold           = var.latency_threshold_ms
  period              = local.common_lambda_alarm.period
  evaluation_periods  = local.common_lambda_alarm.evaluation_periods
  treat_missing_data  = local.common_lambda_alarm.treat_missing_data
  actions_enabled     = local.common_lambda_alarm.actions_enabled
  alarm_actions       = [var.alarm_topic_arn]
  dimensions = {
    FunctionName = var.fastapi_lambda_function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "fastapi_throttles" {
  alarm_name          = "${var.project_name}-fastapi-throttles"
  alarm_description   = "FastAPI Lambda throttling detected"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  metric_name         = "Throttles"
  namespace           = local.common_lambda_alarm.namespace
  statistic           = "Sum"
  threshold           = 1
  period              = local.common_lambda_alarm.period
  evaluation_periods  = local.common_lambda_alarm.evaluation_periods
  treat_missing_data  = local.common_lambda_alarm.treat_missing_data
  actions_enabled     = local.common_lambda_alarm.actions_enabled
  alarm_actions       = [var.alarm_topic_arn]
  dimensions = {
    FunctionName = var.fastapi_lambda_function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "s3_lambda_errors" {
  alarm_name          = "${var.project_name}-ingest-errors"
  alarm_description   = "S3 ingestion Lambda errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  metric_name         = "Errors"
  namespace           = local.common_lambda_alarm.namespace
  statistic           = "Sum"
  threshold           = 1
  period              = local.common_lambda_alarm.period
  evaluation_periods  = local.common_lambda_alarm.evaluation_periods
  treat_missing_data  = local.common_lambda_alarm.treat_missing_data
  actions_enabled     = local.common_lambda_alarm.actions_enabled
  alarm_actions       = [var.alarm_topic_arn]
  dimensions = {
    FunctionName = var.s3_lambda_function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "s3_lambda_duration" {
  alarm_name          = "${var.project_name}-ingest-duration"
  alarm_description   = "S3 ingestion Lambda duration exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  metric_name         = "Duration"
  namespace           = local.common_lambda_alarm.namespace
  extended_statistic  = "p95"
  threshold           = var.latency_threshold_ms
  period              = local.common_lambda_alarm.period
  evaluation_periods  = local.common_lambda_alarm.evaluation_periods
  treat_missing_data  = local.common_lambda_alarm.treat_missing_data
  actions_enabled     = local.common_lambda_alarm.actions_enabled
  alarm_actions       = [var.alarm_topic_arn]
  dimensions = {
    FunctionName = var.s3_lambda_function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "pipeline_errors" {
  alarm_name          = "${var.project_name}-pipeline-errors"
  alarm_description   = "Pipeline worker Lambda errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  metric_name         = "Errors"
  namespace           = local.common_lambda_alarm.namespace
  statistic           = "Sum"
  threshold           = 1
  period              = local.common_lambda_alarm.period
  evaluation_periods  = local.common_lambda_alarm.evaluation_periods
  treat_missing_data  = local.common_lambda_alarm.treat_missing_data
  actions_enabled     = local.common_lambda_alarm.actions_enabled
  alarm_actions       = [var.alarm_topic_arn]
  dimensions = {
    FunctionName = var.pipeline_worker_lambda_name
  }
}

resource "aws_cloudwatch_metric_alarm" "pipeline_duration" {
  alarm_name          = "${var.project_name}-pipeline-duration"
  alarm_description   = "Pipeline worker Lambda duration exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  metric_name         = "Duration"
  namespace           = local.common_lambda_alarm.namespace
  extended_statistic  = "p95"
  threshold           = var.latency_threshold_ms
  period              = local.common_lambda_alarm.period
  evaluation_periods  = local.common_lambda_alarm.evaluation_periods
  treat_missing_data  = local.common_lambda_alarm.treat_missing_data
  actions_enabled     = local.common_lambda_alarm.actions_enabled
  alarm_actions       = [var.alarm_topic_arn]
  dimensions = {
    FunctionName = var.pipeline_worker_lambda_name
  }
}

resource "aws_cloudwatch_metric_alarm" "sfn_failed" {
  alarm_name          = "${var.project_name}-sfn-failed"
  alarm_description   = "Step Functions execution failed count"
  namespace           = "AWS/States"
  metric_name         = "ExecutionsFailed"
  statistic           = "Sum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  period              = 300
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  dimensions = {
    StateMachineArn = var.state_machine_arn
  }
}

resource "aws_cloudwatch_metric_alarm" "sfn_timeout" {
  alarm_name          = "${var.project_name}-sfn-timeout"
  alarm_description   = "Step Functions executions timed out"
  namespace           = "AWS/States"
  metric_name         = "ExecutionsTimedOut"
  statistic           = "Sum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  period              = 300
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  dimensions = {
    StateMachineArn = var.state_machine_arn
  }
}

resource "aws_cloudwatch_metric_alarm" "sfn_throttled" {
  alarm_name          = "${var.project_name}-sfn-throttled"
  alarm_description   = "Step Functions throttled executions detected"
  namespace           = "AWS/States"
  metric_name         = "ExecutionThrottled"
  statistic           = "Sum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  period              = 300
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  dimensions = {
    StateMachineArn = var.state_machine_arn
  }
}

# ====================
# SageMaker Endpoint Monitoring
# ====================

resource "aws_cloudwatch_metric_alarm" "sagemaker_invocation_errors" {
  alarm_name          = "${var.project_name}-sagemaker-invocation-errors"
  alarm_description   = "SageMaker endpoint invocation errors detected"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  metric_name         = "ModelInvocationErrors"
  namespace           = "AWS/SageMaker"
  statistic           = "Sum"
  threshold           = 1
  period              = 300
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  actions_enabled     = true
  alarm_actions       = [var.alarm_topic_arn]

  dimensions = {
    EndpointName = var.sagemaker_endpoint_name
    VariantName  = "AllTraffic"
  }
}
