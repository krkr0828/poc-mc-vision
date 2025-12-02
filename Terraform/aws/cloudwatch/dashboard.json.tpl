{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 3,
      "properties": {
        "view": "singleValue",
        "region": ${region},
        "title": "Step Functions - 実行サマリー（過去1時間）",
        "period": 3600,
        "metrics": [
          [ "AWS/States", "ExecutionsStarted", "StateMachineArn", ${state_machine_arn}, { "label": "実行開始", "stat": "Sum" } ],
          [ ".", "ExecutionsSucceeded", ".", ".", { "label": "成功", "stat": "Sum" } ],
          [ ".", "ExecutionsFailed", ".", ".", { "label": "失敗", "stat": "Sum" } ],
          [ ".", "ExecutionsTimedOut", ".", ".", { "label": "タイムアウト", "stat": "Sum" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "view": "timeSeries",
        "region": ${region},
        "title": "Step Functions - 実行ステータス推移",
        "stat": "Sum",
        "period": 300,
        "yAxis": { "left": { "min": 0 } },
        "metrics": [
          [ "AWS/States", "ExecutionsStarted", "StateMachineArn", ${state_machine_arn}, { "label": "開始", "color": "#1f77b4" } ],
          [ ".", "ExecutionsSucceeded", ".", ".", { "label": "成功", "color": "#2ca02c" } ],
          [ ".", "ExecutionsFailed", ".", ".", { "label": "失敗", "color": "#d62728" } ],
          [ ".", "ExecutionsTimedOut", ".", ".", { "label": "タイムアウト", "color": "#ff7f0e" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 3,
      "width": 12,
      "height": 6,
      "properties": {
        "view": "timeSeries",
        "region": ${region},
        "title": "Step Functions - 実行時間（ms）",
        "period": 300,
        "yAxis": { "left": { "min": 0 } },
        "metrics": [
          [ "AWS/States", "ExecutionTime", "StateMachineArn", ${state_machine_arn}, { "label": "P50", "stat": "p50" } ],
          [ ".", ".", ".", ".", { "label": "P95", "stat": "p95" } ],
          [ ".", ".", ".", ".", { "label": "P99", "stat": "p99" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 9,
      "width": 12,
      "height": 6,
      "properties": {
        "view": "timeSeries",
        "region": ${region},
        "title": "SageMaker - 呼び出し状況",
        "period": 300,
        "stat": "Sum",
        "yAxis": { "left": { "min": 0 } },
        "metrics": [
          [ "AWS/SageMaker", "Invocations", "EndpointName", ${sagemaker_endpoint}, "VariantName", "AllTraffic", { "label": "呼び出し回数" } ],
          [ ".", "ModelInvocationErrors", ".", ".", ".", ".", { "label": "エラー数" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 9,
      "width": 12,
      "height": 6,
      "properties": {
        "view": "timeSeries",
        "region": ${region},
        "title": "SageMaker - レイテンシ（μs）",
        "period": 300,
        "yAxis": { "left": { "min": 0 } },
        "metrics": [
          [ "AWS/SageMaker", "ModelLatency", "EndpointName", ${sagemaker_endpoint}, "VariantName", "AllTraffic", { "label": "モデルレイテンシ P50", "stat": "p50" } ],
          [ ".", ".", ".", ".", ".", ".", { "label": "P95", "stat": "p95" } ],
          [ ".", "OverheadLatency", ".", ".", ".", ".", { "label": "オーバーヘッド P95", "stat": "p95" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 15,
      "width": 12,
      "height": 6,
      "properties": {
        "view": "timeSeries",
        "region": ${region},
        "title": "Lambda Pipeline Worker - 呼び出し状況",
        "period": 300,
        "stat": "Sum",
        "yAxis": { "left": { "min": 0 } },
        "metrics": [
          [ "AWS/Lambda", "Invocations", "FunctionName", ${pipeline_worker_name}, { "label": "呼び出し" } ],
          [ ".", "Errors", ".", ".", { "label": "エラー" } ],
          [ ".", "Throttles", ".", ".", { "label": "スロットリング" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 15,
      "width": 12,
      "height": 6,
      "properties": {
        "view": "timeSeries",
        "region": ${region},
        "title": "Lambda Pipeline Worker - レイテンシ（ms）",
        "period": 300,
        "yAxis": { "left": { "min": 0 } },
        "metrics": [
          [ "AWS/Lambda", "Duration", "FunctionName", ${pipeline_worker_name}, { "label": "P50", "stat": "p50" } ],
          [ ".", ".", ".", ".", { "label": "P95", "stat": "p95" } ],
          [ ".", ".", ".", ".", { "label": "P99", "stat": "p99" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 21,
      "width": 12,
      "height": 6,
      "properties": {
        "view": "timeSeries",
        "region": ${region},
        "title": "FastAPI Lambda - 状況",
        "period": 300,
        "yAxis": { "left": { "min": 0 } },
        "metrics": [
          [ "AWS/Lambda", "Invocations", "FunctionName", ${fastapi_lambda_name}, { "label": "呼び出し" } ],
          [ ".", "Errors", ".", ".", { "label": "エラー" } ],
          [ ".", "Duration", ".", ".", { "label": "Duration P95", "stat": "p95" } ]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 21,
      "width": 12,
      "height": 6,
      "properties": {
        "view": "timeSeries",
        "region": ${region},
        "title": "DynamoDB - 状況",
        "period": 300,
        "yAxis": { "left": { "min": 0 } },
        "metrics": [
          [ "AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", ${dynamodb_table_name}, { "label": "書き込み消費WCU" } ],
          [ ".", "ThrottledRequests", ".", ".", { "label": "スロットル" } ],
          [ ".", "SuccessfulRequestLatency", ".", ".", "Operation", "PutItem", { "label": "レイテンシ P95", "stat": "p95" } ]
        ]
      }
    }
  ]
}
