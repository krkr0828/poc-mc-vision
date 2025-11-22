{
  "Comment": "PoC MC Vision multi-model pipeline orchestrated by Step Functions",
  "StartAt": "InvokeSageMaker",
  "States": {
    "InvokeSageMaker": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${lambda_worker_arn}",
        "Payload": {
          "task": "sagemaker",
          "s3_key.$": "$.s3_key",
          "request_id.$": "$.requestId"
        }
      },
      "ResultSelector": {
        "payload.$": "$.Payload"
      },
      "ResultPath": "$.sagemaker",
      "Next": "ParallelModels",
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ],
      "Catch": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "ResultPath": "$.error",
          "Next": "NotifyFailure"
        }
      ]
    },
    "ParallelModels": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "InvokeBedrock",
          "States": {
            "InvokeBedrock": {
              "Type": "Task",
              "Resource": "arn:aws:states:::lambda:invoke",
              "Parameters": {
                "FunctionName": "${lambda_worker_arn}",
                "Payload": {
                  "task": "bedrock",
                  "s3_key.$": "$.s3_key",
                  "request_id.$": "$.requestId"
                }
              },
              "ResultSelector": {
                "bedrock.$": "$.Payload"
              },
              "ResultPath": "$.bedrock",
              "Retry": [
                {
                  "ErrorEquals": [
                    "Lambda.ServiceException",
                    "Lambda.AWSLambdaException",
                    "Lambda.SdkClientException",
                    "Lambda.TooManyRequestsException"
                  ],
                  "IntervalSeconds": 2,
                  "MaxAttempts": 3,
                  "BackoffRate": 2.0
                }
              ],
              "End": true
            }
          }
        },
        {
          "StartAt": "InvokeAzure",
          "States": {
            "InvokeAzure": {
              "Type": "Task",
              "Resource": "arn:aws:states:::lambda:invoke",
              "Parameters": {
                "FunctionName": "${lambda_worker_arn}",
                "Payload": {
                  "task": "azure",
                  "s3_key.$": "$.s3_key",
                  "request_id.$": "$.requestId"
                }
              },
              "ResultSelector": {
                "azure.$": "$.Payload"
              },
              "ResultPath": "$.azure",
              "Retry": [
                {
                  "ErrorEquals": [
                    "Lambda.ServiceException",
                    "Lambda.AWSLambdaException",
                    "Lambda.SdkClientException",
                    "Lambda.TooManyRequestsException"
                  ],
                  "IntervalSeconds": 2,
                  "MaxAttempts": 3,
                  "BackoffRate": 2.0
                }
              ],
              "End": true
            }
          }
        }
      ],
      "ResultSelector": {
        "bedrock.$": "$[0].bedrock",
        "azure.$": "$[1].azure"
      },
      "ResultPath": "$.parallelResults",
      "Next": "PersistResults",
      "Catch": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "ResultPath": "$.error",
          "Next": "NotifyFailure"
        }
      ]
    },
    "PersistResults": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:dynamodb:putItem",
      "Parameters": {
        "TableName": "${ddb_table_name}",
        "Item": {
          "request_id": {
            "S.$": "$.requestId"
          },
          "s3_key": {
            "S.$": "$.s3_key"
          },
          "sagemaker": {
            "S.$": "States.JsonToString($.sagemaker.payload)"
          },
          "bedrock": {
            "S.$": "States.JsonToString($.parallelResults.bedrock)"
          },
          "azure": {
            "S.$": "States.JsonToString($.parallelResults.azure)"
          },
          "created_at": {
            "N.$": "States.Format('{}', $.timestamps.created)"
          },
          "expire_at": {
            "N.$": "States.Format('{}', $.timestamps.expires)"
          }
        }
      },
      "ResultPath": "$.ddb",
      "Next": "NotifyComplete",
      "Retry": [
        {
          "ErrorEquals": [
            "DynamoDB.ProvisionedThroughputExceededException",
            "DynamoDB.RequestLimitExceeded",
            "DynamoDB.ThrottlingException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ],
      "Catch": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "ResultPath": "$.error",
          "Next": "NotifyFailure"
        }
      ]
    },
    "NotifyComplete": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:sns:publish",
      "Parameters": {
        "TopicArn": "${sns_topic_arn}",
        "Subject": "PoC MC Vision pipeline completed",
        "Message.$": "States.Format('\\{\"requestId\": \"{}\", \"status\": \"SUCCEEDED\", \"s3_key\": \"{}\"\\}', $.requestId, $.s3_key)"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "SNS.SdkClientException",
            "SNS.ThrottledException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ],
      "End": true
    },
    "NotifyFailure": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:sns:publish",
      "Parameters": {
        "TopicArn": "${sns_topic_arn}",
        "Subject": "PoC MC Vision pipeline failed",
        "Message.$": "States.Format('\\{\"requestId\": \"{}\", \"status\": \"FAILED\"\\}', $.requestId)"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "SNS.SdkClientException",
            "SNS.ThrottledException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ],
      "End": true
    }
  }
}
