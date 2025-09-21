# IAM role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project}-lambda-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Zip the Lambda source
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_s3_object" "lambda_zip" {
  bucket                 = module.code_bucket.bucket_name
  key                    = "lambda/lambda.zip"
  source                 = data.archive_file.lambda_zip.output_path
  etag                   = filemd5(data.archive_file.lambda_zip.output_path)
  content_type           = "application/zip"
  server_side_encryption = "AES256"
}

# Lambda function
resource "aws_lambda_function" "api_reader" {
  function_name    = "${var.project}-api-reader"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "youtube-api.handler"
  runtime          = "python3.12"

  s3_bucket        = module.code_bucket.bucket_name
  s3_key           = aws_s3_object.lambda_zip.key

  timeout          = 15

  environment {
    variables = {
    }
  }
}
