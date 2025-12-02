data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# ====================
# Lambda IAM Role
# ====================

resource "aws_iam_role" "lambda" {
  name = var.lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Lambda Basic Execution Role (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ====================
# FastAPI Lambda IAM Role
# ====================

resource "aws_iam_role" "fastapi" {
  name = var.fastapi_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fastapi_basic" {
  role       = aws_iam_role.fastapi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "fastapi_permissions" {
  name = "${var.project_name}-fastapi-policy"
  role = aws_iam_role.fastapi.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution",
          "states:DescribeExecution",
          "states:GetExecutionHistory"
        ]
        Resource = "*"
      }
    ]
  })
}

# ====================
# Pipeline Worker IAM Role
# ====================

resource "aws_iam_role" "pipeline_worker" {
  name = var.pipeline_worker_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "pipeline_worker_basic" {
  role       = aws_iam_role.pipeline_worker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "pipeline_worker_access" {
  name = "${var.project_name}-pipeline-worker-policy"
  role = aws_iam_role.pipeline_worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:InvokeEndpoint"
        ]
        Resource = "arn:aws:sagemaker:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:endpoint/${var.sagemaker_endpoint_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.bedrock_model_id}"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:ApplyGuardrail"
        ]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:guardrail/*"
      }
    ]
  })
}

# Bedrock Invoke Policy (モデル単位で制限)
resource "aws_iam_role_policy" "lambda_bedrock" {
  name = "${var.project_name}-lambda-bedrock-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.bedrock_model_id}"
      }
    ]
  })
}

# ====================
# SageMaker IAM Role
# ====================

resource "aws_iam_role" "sagemaker" {
  name = "${var.project_name}-sagemaker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# S3 Access for SageMaker Model Data
resource "aws_iam_role_policy" "sagemaker_s3" {
  name = "${var.project_name}-sagemaker-s3-policy"
  role = aws_iam_role.sagemaker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*",
          "arn:aws:s3:::${var.lambda_zip_bucket}",
          "arn:aws:s3:::${var.lambda_zip_bucket}/*"
        ]
      }
    ]
  })
}

# CloudWatch Logs 出力用の最小権限
resource "aws_iam_role_policy" "sagemaker_logs" {
  name = "${var.project_name}-sagemaker-logs-policy"
  role = aws_iam_role.sagemaker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/sagemaker/*"
      }
    ]
  })
}

# ECR Access for SageMaker to pull container images
resource "aws_iam_role_policy" "sagemaker_ecr" {
  name = "${var.project_name}-sagemaker-ecr-policy"
  role = aws_iam_role.sagemaker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = [
          var.ecr_repository_arn,
          "arn:aws:ecr:*:763104351884:repository/*"
        ]
      }
    ]
  })
}
