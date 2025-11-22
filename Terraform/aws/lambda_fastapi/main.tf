resource "aws_lambda_function" "fastapi" {
  function_name = var.function_name
  package_type  = "Image"
  role          = var.lambda_role_arn
  image_uri     = var.image_uri
  timeout       = var.timeout
  memory_size   = var.memory_size

  environment {
    variables = var.environment
  }

  dynamic "image_config" {
    for_each = var.image_command == null ? [] : [1]
    content {
      command = var.image_command
    }
  }
}

resource "aws_lambda_function_url" "fastapi" {
  count = var.create_function_url ? 1 : 0

  function_name      = aws_lambda_function.fastapi.function_name
  authorization_type = var.function_url_auth_type

  cors {
    allow_credentials = true
    allow_methods     = ["*"]
    allow_origins     = ["*"]
    allow_headers     = ["*"]
  }
}
