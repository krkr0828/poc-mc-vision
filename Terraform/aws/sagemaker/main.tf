# ====================
# SageMaker Model
# ====================

resource "aws_sagemaker_model" "this" {
  name               = var.model_name
  execution_role_arn = var.execution_role_arn

  primary_container {
    # PyTorch推論用のコンテナイメージ（ap-northeast-1）
    image          = "763104351884.dkr.ecr.ap-northeast-1.amazonaws.com/pytorch-inference:2.0.1-cpu-py310"
    model_data_url = var.model_data_url
  }
}

# ====================
# SageMaker Endpoint Configuration (Serverless)
# ====================

resource "aws_sagemaker_endpoint_configuration" "this" {
  name = "${var.project_name}-endpoint-config"

  production_variants {
    variant_name = "AllTraffic"
    model_name   = aws_sagemaker_model.this.name

    serverless_config {
      memory_size_in_mb = var.memory_size_in_mb
      max_concurrency   = var.max_concurrency
    }
  }
}

# ====================
# SageMaker Endpoint
# ====================

resource "aws_sagemaker_endpoint" "this" {
  name                 = var.endpoint_name
  endpoint_config_name = aws_sagemaker_endpoint_configuration.this.name

  tags = {
    Name        = var.endpoint_name
    Environment = "poc"
  }
}

# ====================
# Auto Scaling (オプション)
# ====================
# Serverlessエンドポイントは自動スケールするため、
# Application Auto Scalingの設定は不要
# 本番環境で固定インスタンスを使用する場合は、
# aws_appautoscaling_target および aws_appautoscaling_policy を追加
