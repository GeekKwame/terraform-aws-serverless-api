resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix       = var.project_name
  bucket_name       = coalesce(var.bucket_name, "${var.project_name}-storage-${random_id.suffix.hex}")
  lambda_zip_path   = "${path.module}/lambda/lambda_function.zip"
  lambda_source     = "${path.module}/lambda/lambda_function.py"
  execution_arn     = aws_api_gateway_rest_api.student_api.execution_arn
  api_execution_arn = "${local.execution_arn}/*/${aws_api_gateway_method.get_method.http_method}${aws_api_gateway_resource.students.path}"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = local.lambda_source
  output_path = local.lambda_zip_path
}

resource "aws_s3_bucket" "storage_bucket" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "bucket_block" {
  bucket = aws_s3_bucket.storage_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "lambda_role" {
  name = "${local.name_prefix}-lambda-role"

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

resource "aws_iam_policy" "s3_policy" {
  name = "${local.name_prefix}-lambda-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.storage_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "student_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${local.name_prefix}-api"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.storage_bucket.bucket
    }
  }
}

resource "aws_api_gateway_rest_api" "student_api" {
  name = "${local.name_prefix}-api"
}

resource "aws_api_gateway_resource" "students" {
  rest_api_id = aws_api_gateway_rest_api.student_api.id
  parent_id   = aws_api_gateway_rest_api.student_api.root_resource_id
  path_part   = "students"
}

resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.student_api.id
  resource_id   = aws_api_gateway_resource.students.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.student_api.id
  resource_id             = aws_api_gateway_resource.students.id
  http_method             = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.student_lambda.invoke_arn
}

resource "aws_lambda_permission" "api_permission" {
  statement_id  = "AllowApiGatewayExecution"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.student_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = local.api_execution_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.student_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.students.id,
      aws_api_gateway_method.get_method.id,
      aws_api_gateway_integration.get_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.get_integration
  ]
}

resource "aws_api_gateway_stage" "prod" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.student_api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
}

resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = coalesce(var.state_bucket_name, "${var.project_name}-tfstate-${random_id.suffix.hex}")
}

resource "aws_s3_bucket_versioning" "terraform_state_bucket" {
  bucket = aws_s3_bucket.terraform_state_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = coalesce(var.lock_table_name, "${var.project_name}-terraform-locks-${random_id.suffix.hex}")
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
