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
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "0"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    name = "s3-lambda"
  }
}

resource "aws_iam_role_policy_attachment" "attach-policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_sqs_queue" "async-queue" {
  name = "async-queue"
}

resource "aws_lambda_function" "s3_notifier" {
  filename      = "lambda_payload.zip"
  function_name = "s3-notifier"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda.lambda_handler"

  runtime = "python3.9"
}

resource "aws_lambda_function_event_invoke_config" "notifier-destination" {

  function_name = aws_lambda_function.s3_notifier.arn

  destination_config {
    on_failure {
      destination = aws_sqs_queue.async-queue.arn
    }

    on_success {
      destination = aws_sqs_queue.async-queue.arn
    }
  }
}

resource "aws_s3_bucket" "s3_event" {
  bucket = "s3-event-terraform-rp"
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_notifier.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_event.arn
}

resource "aws_s3_bucket_notification" "object_created" {
  bucket = aws_s3_bucket.s3_event.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_notifier.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

