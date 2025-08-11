# Lambda function IAM Role
module "lambda_function_iam_role" {
  source             = "./modules/iam"
  role_name          = "lambda-function-iam-role"
  role_description   = "lambda-function-iam-role"
  policy_name        = "lambda-function-iam-policy"
  policy_description = "lambda-function-iam-policy"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                  "Service": "lambda.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
    EOF
  policy             = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
              ],
              "Resource": "arn:aws:logs:*:*:*",
              "Effect": "Allow"
          }
      ]
    }
    EOF
}

module "create_user_code_bucket" {
  source      = "./modules/s3"
  bucket_name = "create-user-function-code"
  objects = [
    {
      key    = "create_user.zip"
      source = "./files/create_user.zip"
    }
  ]
  versioning_enabled = "Enabled"
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "POST", "GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
  force_destroy = true
}

module "get_users_code_bucket" {
  source      = "./modules/s3"
  bucket_name = "get-users-function-code"
  objects = [
    {
      key    = "get_users.zip"
      source = "./files/get_users.zip"
    }
  ]
  versioning_enabled = "Enabled"
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "POST", "GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
  force_destroy = true
}

module "delete_user_code_bucket" {
  source      = "./modules/s3"
  bucket_name = "delete-user-function-code"
  objects = [
    {
      key    = "delete_user.zip"
      source = "./files/delete_user.zip"
    }
  ]
  versioning_enabled = "Enabled"
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "POST", "GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
  force_destroy = true
}

# Lambda function to create a user
module "create_user_function" {
  source        = "./modules/lambda"
  function_name = "create-user-function"
  role_arn      = module.lambda_function_iam_role.arn
  env_variables = {}
  handler       = "create_user.lambda_handler"
  runtime       = "python3.12"
  s3_bucket     = module.create_user_code_bucket.bucket
  s3_key        = "create_user.zip"
  depends_on    = [module.create_user_code_bucket]
}

# Lambda function to get a list of users
module "get_users_function" {
  source        = "./modules/lambda"
  function_name = "get-users-function"
  role_arn      = module.lambda_function_iam_role.arn
  env_variables = {}
  handler       = "get_users.lambda_handler"
  runtime       = "python3.12"
  s3_bucket     = module.get_users_code_bucket.bucket
  s3_key        = "get_users.zip"
  depends_on    = [module.get_users_code_bucket]
}

# Lambda function to get a list of users
module "delete_user_function" {
  source        = "./modules/lambda"
  function_name = "delete-user-function"
  role_arn      = module.lambda_function_iam_role.arn
  env_variables = {}
  handler       = "delete_user.lambda_handler"
  runtime       = "python3.12"
  s3_bucket     = module.delete_user_code_bucket.bucket
  s3_key        = "delete_user.zip"
  depends_on    = [module.delete_user_code_bucket]
}

# DynamoDB Table
module "users_table" {
  source = "./modules/dynamodb"
  name   = "users"
  attributes = [
    {
      name = "RecordId"
      type = "S"
    },
    {
      name = "name"
      type = "S"
    }
  ]
  billing_mode          = "PROVISIONED"
  hash_key              = "RecordId"
  range_key             = "name"
  read_capacity         = 20
  write_capacity        = 20
  ttl_attribute_name    = "TimeToExist"
  ttl_attribute_enabled = true
}

# API Gateway configuration
resource "aws_api_gateway_rest_api" "rest_api" {
  name = "api"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "user_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "users"
}

resource "aws_api_gateway_resource" "create_user_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.user_resource.id
  path_part   = "create_user"
}

resource "aws_api_gateway_method" "create_user_resource_method" {
  rest_api_id      = aws_api_gateway_rest_api.rest_api.id
  resource_id      = aws_api_gateway_resource.create_user_resource.id
  api_key_required = false
  http_method      = "ANY"
  authorization    = "NONE"
}

resource "aws_api_gateway_integration" "create_user_resource_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.create_user_resource.id
  http_method             = aws_api_gateway_method.create_user_resource_method.http_method
  integration_http_method = "ANY"
  type                    = "AWS_PROXY"
  uri                     = module.create_user_function.invoke_arn
}

resource "aws_api_gateway_method_response" "create_user_resource_method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.create_user_resource.id
  http_method = aws_api_gateway_method.create_user_resource_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "create_user_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.create_user_resource.id
  http_method = aws_api_gateway_method.create_user_resource_method.http_method
  status_code = aws_api_gateway_method_response.create_user_resource_method_response_200.status_code
  depends_on = [
    aws_api_gateway_integration.create_user_resource_method_integration
  ]
}

# ---------------------------------------------------------------------------------------------------

resource "aws_api_gateway_resource" "get_users_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.user_resource.id
  path_part   = "get_users"
}

resource "aws_api_gateway_method" "get_users_resource_method" {
  rest_api_id      = aws_api_gateway_rest_api.rest_api.id
  resource_id      = aws_api_gateway_resource.get_users_resource.id
  api_key_required = false
  http_method      = "ANY"
  authorization    = "NONE"
}

resource "aws_api_gateway_integration" "get_users_resource_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.get_users_resource.id
  http_method             = aws_api_gateway_method.get_users_resource_method.http_method
  integration_http_method = "ANY"
  type                    = "AWS_PROXY"
  uri                     = module.get_users_function.invoke_arn
}

resource "aws_api_gateway_method_response" "get_users_resource_method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.get_users_resource.id
  http_method = aws_api_gateway_method.get_users_resource_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "get_users_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.get_users_resource.id
  http_method = aws_api_gateway_method.get_users_resource_method.http_method
  status_code = aws_api_gateway_method_response.get_users_resource_method_response_200.status_code
  depends_on = [
    aws_api_gateway_integration.get_users_resource_method_integration
  ]
}

# ---------------------------------------------------------------------------------------------------

resource "aws_api_gateway_resource" "delete_user_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.user_resource.id
  path_part   = "delete_user"
}

resource "aws_api_gateway_method" "delete_user_resource_method" {
  rest_api_id      = aws_api_gateway_rest_api.rest_api.id
  resource_id      = aws_api_gateway_resource.delete_user_resource.id
  api_key_required = false
  http_method      = "ANY"
  authorization    = "NONE"
}

resource "aws_api_gateway_integration" "delete_user_resource_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.delete_user_resource.id
  http_method             = aws_api_gateway_method.delete_user_resource_method.http_method
  integration_http_method = "ANY"
  type                    = "AWS_PROXY"
  uri                     = module.delete_user_function.invoke_arn
}

resource "aws_api_gateway_method_response" "delete_user_resource_method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.delete_user_resource.id
  http_method = aws_api_gateway_method.delete_user_resource_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "delete_user_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.delete_user_resource.id
  http_method = aws_api_gateway_method.delete_user_resource_method.http_method
  status_code = aws_api_gateway_method_response.delete_user_resource_method_response_200.status_code
  depends_on = [
    aws_api_gateway_integration.delete_user_resource_method_integration
  ]
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_api_gateway_integration.create_user_resource_method_integration, aws_api_gateway_integration.get_users_resource_method_integration, aws_api_gateway_integration.delete_user_resource_method_integration]
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = "prod"
}