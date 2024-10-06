terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.62.0"
    }

    archive = {
      source = "hashicorp/archive"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

provider "archive" {}

resource "aws_iam_policy" "lambda_policy" {
  name   = "lambda_policy"
  policy = data.aws_iam_policy_document.lambda_policy_document.json
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_api_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "attach-policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "lambda_api_proxy" {
  filename      = "lambda_payload.zip"
  function_name = "api-backend"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda.lambda_handler"

  runtime = "python3.9"
}

resource "aws_api_gateway_rest_api" "studentAPI" {
  name = "studentAPI"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "students" {
  path_part   = "students"
  parent_id   = aws_api_gateway_rest_api.studentAPI.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.studentAPI.id
}

resource "aws_api_gateway_method" "getStudents" {
  rest_api_id   = aws_api_gateway_rest_api.studentAPI.id
  resource_id   = aws_api_gateway_resource.students.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.studentAPI.id
  resource_id             = aws_api_gateway_resource.students.id
  http_method             = aws_api_gateway_method.getStudents.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_api_proxy.invoke_arn
}

resource "aws_lambda_permission" "Allow_API_Gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_api_proxy.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${var.myregion}:${var.accountId}:${aws_api_gateway_rest_api.studentAPI.id}/*/${aws_api_gateway_method.getStudents.http_method}${aws_api_gateway_resource.students.path}"
}

resource "aws_api_gateway_deployment" "dev" {
  rest_api_id = aws_api_gateway_rest_api.studentAPI.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.studentAPI.body))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.getStudents,
    aws_api_gateway_integration.lambda_integration
  ]
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.dev.id
  rest_api_id   = aws_api_gateway_rest_api.studentAPI.id
  stage_name    = "dev"
}



