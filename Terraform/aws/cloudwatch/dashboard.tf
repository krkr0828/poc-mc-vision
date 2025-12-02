# CloudWatch Dashboard for Operations Monitoring

data "aws_region" "current" {}

resource "aws_cloudwatch_dashboard" "operations" {
  dashboard_name = "${var.project_name}-operations"

  dashboard_body = jsonencode({
    widgets = [
      # ========================================
      # Section 1: システム全体概要
      # ========================================

      # 数値ウィジェット: Step Functions メトリクス
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/States", "ExecutionsStarted", { StateMachineArn = var.state_machine_arn }, { stat = "Sum", label = "実行開始" }],
            [".", "ExecutionsSucceeded", { StateMachineArn = var.state_machine_arn }, { stat = "Sum", label = "成功" }],
            [".", "ExecutionsFailed", { StateMachineArn = var.state_machine_arn }, { stat = "Sum", label = "失敗" }],
            [".", "ExecutionsTimedOut", { StateMachineArn = var.state_machine_arn }, { stat = "Sum", label = "タイムアウト" }]
          ]
          view   = "singleValue"
          region = data.aws_region.current.name
          title  = "Step Functions - 実行サマリー（過去1時間）"
          period = 3600
        }
        width  = 12
        height = 3
        x      = 0
        y      = 0
      },

      # 時系列グラフ: Step Functions 実行状況
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/States", "ExecutionsStarted", { StateMachineArn = var.state_machine_arn }, { stat = "Sum", label = "開始", color = "#1f77b4" }],
            [".", "ExecutionsSucceeded", { StateMachineArn = var.state_machine_arn }, { stat = "Sum", label = "成功", color = "#2ca02c" }],
            [".", "ExecutionsFailed", { StateMachineArn = var.state_machine_arn }, { stat = "Sum", label = "失敗", color = "#d62728" }],
            [".", "ExecutionsTimedOut", { StateMachineArn = var.state_machine_arn }, { stat = "Sum", label = "タイムアウト", color = "#ff7f0e" }]
          ]
          view   = "timeSeries"
          region = data.aws_region.current.name
          title  = "Step Functions - 実行ステータス推移"
          period = 300
          stat   = "Sum"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 0
      },

      # Step Functions レイテンシ
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/States", "ExecutionTime", { StateMachineArn = var.state_machine_arn }, { stat = "p50", label = "P50" }],
            ["...", { stat = "p95", label = "P95" }],
            ["...", { stat = "p99", label = "P99" }]
          ]
          view   = "timeSeries"
          region = data.aws_region.current.name
          title  = "Step Functions - 実行時間（ms）"
          period = 300
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 3
      },

      # ========================================
      # Section 2: AI推論サービス
      # ========================================

      # SageMaker エンドポイント
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SageMaker", "Invocations", { EndpointName = var.sagemaker_endpoint_name, VariantName = "AllTraffic" }, { stat = "Sum", label = "呼び出し回数" }],
            [".", "ModelInvocationErrors", { EndpointName = var.sagemaker_endpoint_name, VariantName = "AllTraffic" }, { stat = "Sum", label = "エラー数" }]
          ]
          view   = "timeSeries"
          region = data.aws_region.current.name
          title  = "SageMaker - 呼び出し状況"
          period = 300
          stat   = "Sum"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 9
      },

      # SageMaker レイテンシ
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SageMaker", "ModelLatency", { EndpointName = var.sagemaker_endpoint_name, VariantName = "AllTraffic" }, { stat = "p50", label = "モデルレイテンシ P50" }],
            ["...", { stat = "p95", label = "P95" }],
            [".", "OverheadLatency", { EndpointName = var.sagemaker_endpoint_name, VariantName = "AllTraffic" }, { stat = "p95", label = "オーバーヘッド P95" }]
          ]
          view   = "timeSeries"
          region = data.aws_region.current.name
          title  = "SageMaker - レイテンシ（μs）"
          period = 300
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 9
      },

      # Lambda Pipeline Worker
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { FunctionName = var.pipeline_worker_lambda_name }, { stat = "Sum", label = "呼び出し" }],
            [".", "Errors", { FunctionName = var.pipeline_worker_lambda_name }, { stat = "Sum", label = "エラー" }],
            [".", "Throttles", { FunctionName = var.pipeline_worker_lambda_name }, { stat = "Sum", label = "スロットリング" }]
          ]
          view   = "timeSeries"
          region = data.aws_region.current.name
          title  = "Lambda Pipeline Worker - 呼び出し状況"
          period = 300
          stat   = "Sum"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 15
      },

      # Lambda Pipeline Worker レイテンシ
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", { FunctionName = var.pipeline_worker_lambda_name }, { stat = "p50", label = "P50" }],
            ["...", { stat = "p95", label = "P95" }],
            ["...", { stat = "p99", label = "P99" }]
          ]
          view   = "timeSeries"
          region = data.aws_region.current.name
          title  = "Lambda Pipeline Worker - レイテンシ（ms）"
          period = 300
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 15
      },

      # ========================================
      # Section 3: API & データストア
      # ========================================

      # FastAPI Lambda
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { FunctionName = var.fastapi_lambda_function_name }, { stat = "Sum", label = "呼び出し" }],
            [".", "Errors", { FunctionName = var.fastapi_lambda_function_name }, { stat = "Sum", label = "エラー" }],
            [".", "Duration", { FunctionName = var.fastapi_lambda_function_name }, { stat = "p95", label = "Duration P95" }]
          ]
          view   = "timeSeries"
          region = data.aws_region.current.name
          title  = "FastAPI Lambda - 状況"
          period = 300
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 21
      },

      # DynamoDB
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", { TableName = var.dynamodb_table_name }, { stat = "Sum", label = "書き込み消費WCU" }],
            [".", "ThrottledRequests", { TableName = var.dynamodb_table_name }, { stat = "Sum", label = "スロットル" }],
            [".", "SuccessfulRequestLatency", { TableName = var.dynamodb_table_name, Operation = "PutItem" }, { stat = "p95", label = "レイテンシ P95" }]
          ]
          view   = "timeSeries"
          region = data.aws_region.current.name
          title  = "DynamoDB - 状況"
          period = 300
          yAxis = {
            left = {
              min = 0
            }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 21
      }
    ]
  })
}
