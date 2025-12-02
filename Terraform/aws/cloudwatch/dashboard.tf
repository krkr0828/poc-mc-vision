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
            ["AWS/States", "ExecutionsStarted", {
              stat  = "Sum",
              label = "実行開始",
              dimensions = {
                StateMachineArn = var.state_machine_arn
              }
            }],
            [".", "ExecutionsSucceeded", {
              stat  = "Sum",
              label = "成功",
              dimensions = {
                StateMachineArn = var.state_machine_arn
              }
            }],
            [".", "ExecutionsFailed", {
              stat  = "Sum",
              label = "失敗",
              dimensions = {
                StateMachineArn = var.state_machine_arn
              }
            }],
            [".", "ExecutionsTimedOut", {
              stat  = "Sum",
              label = "タイムアウト",
              dimensions = {
                StateMachineArn = var.state_machine_arn
              }
            }]
          ]
          view   = "singleValue"
          region = data.aws_region.current.name
          title  = "Step Functions - 実行サマリー（過去1時間）"
          period = 3600
          stat   = "Sum"
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
            ["AWS/States", "ExecutionsStarted", {
              stat  = "Sum",
              label = "開始",
              color = "#1f77b4",
              dimensions = {
                StateMachineArn = var.state_machine_arn
              }
            }],
            [".", "ExecutionsSucceeded", {
              stat  = "Sum",
              label = "成功",
              color = "#2ca02c",
              dimensions = {
                StateMachineArn = var.state_machine_arn
              }
            }],
            [".", "ExecutionsFailed", {
              stat  = "Sum",
              label = "失敗",
              color = "#d62728",
              dimensions = {
                StateMachineArn = var.state_machine_arn
              }
            }],
            [".", "ExecutionsTimedOut", {
              stat  = "Sum",
              label = "タイムアウト",
              color = "#ff7f0e",
              dimensions = {
                StateMachineArn = var.state_machine_arn
              }
            }]
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
            ["AWS/States", "ExecutionTime", {
              stat  = "p50",
              label = "P50",
              dimensions = {
                StateMachineArn = var.state_machine_arn
              }
            }],
            ["...", {
              stat  = "p95",
              label = "P95",
              dimensions = {
                StateMachineArn = var.state_machine_arn
              }
            }],
            ["...", {
              stat  = "p99",
              label = "P99",
              dimensions = {
                StateMachineArn = var.state_machine_arn
              }
            }]
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
            ["AWS/SageMaker", "Invocations", {
              stat  = "Sum",
              label = "呼び出し回数",
              dimensions = {
                EndpointName = var.sagemaker_endpoint_name
                VariantName  = "AllTraffic"
              }
            }],
            [".", "ModelInvocationErrors", {
              stat  = "Sum",
              label = "エラー数",
              dimensions = {
                EndpointName = var.sagemaker_endpoint_name
                VariantName  = "AllTraffic"
              }
            }]
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
            ["AWS/SageMaker", "ModelLatency", {
              stat  = "p50",
              label = "モデルレイテンシ P50",
              dimensions = {
                EndpointName = var.sagemaker_endpoint_name
                VariantName  = "AllTraffic"
              }
            }],
            ["...", {
              stat  = "p95",
              label = "P95",
              dimensions = {
                EndpointName = var.sagemaker_endpoint_name
                VariantName  = "AllTraffic"
              }
            }],
            [".", "OverheadLatency", {
              stat  = "p95",
              label = "オーバーヘッド P95",
              dimensions = {
                EndpointName = var.sagemaker_endpoint_name
                VariantName  = "AllTraffic"
              }
            }]
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
            ["AWS/Lambda", "Invocations", {
              stat  = "Sum",
              label = "呼び出し",
              dimensions = {
                FunctionName = var.pipeline_worker_lambda_name
              }
            }],
            [".", "Errors", {
              stat  = "Sum",
              label = "エラー",
              dimensions = {
                FunctionName = var.pipeline_worker_lambda_name
              }
            }],
            [".", "Throttles", {
              stat  = "Sum",
              label = "スロットリング",
              dimensions = {
                FunctionName = var.pipeline_worker_lambda_name
              }
            }]
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
            ["AWS/Lambda", "Duration", {
              stat  = "p50",
              label = "P50",
              dimensions = {
                FunctionName = var.pipeline_worker_lambda_name
              }
            }],
            ["...", {
              stat  = "p95",
              label = "P95",
              dimensions = {
                FunctionName = var.pipeline_worker_lambda_name
              }
            }],
            ["...", {
              stat  = "p99",
              label = "P99",
              dimensions = {
                FunctionName = var.pipeline_worker_lambda_name
              }
            }]
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
            ["AWS/Lambda", "Invocations", {
              stat  = "Sum",
              label = "呼び出し",
              dimensions = {
                FunctionName = var.fastapi_lambda_function_name
              }
            }],
            [".", "Errors", {
              stat  = "Sum",
              label = "エラー",
              dimensions = {
                FunctionName = var.fastapi_lambda_function_name
              }
            }],
            [".", "Duration", {
              stat  = "p95",
              label = "Duration P95",
              dimensions = {
                FunctionName = var.fastapi_lambda_function_name
              }
            }]
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
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", {
              stat  = "Sum",
              label = "書き込み消費WCU",
              dimensions = {
                TableName = var.dynamodb_table_name
              }
            }],
            [".", "ThrottledRequests", {
              stat  = "Sum",
              label = "スロットル",
              dimensions = {
                TableName = var.dynamodb_table_name
              }
            }],
            [".", "SuccessfulRequestLatency", {
              stat  = "p95",
              label = "レイテンシ P95",
              dimensions = {
                TableName = var.dynamodb_table_name
                Operation = "PutItem"
              }
            }]
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
