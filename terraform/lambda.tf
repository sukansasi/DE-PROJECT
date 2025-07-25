# zip lambda functions

data "archive_file" "extract_lambda" {
  type        = "zip"
  output_path = "${path.module}/../packages/extract_lambda/function.zip"
  source_file = "${path.module}/../src/extract_lambda.py"
}

data "archive_file" "transform_lambda" {
  type        = "zip"
  output_path = "${path.module}/../packages/transform_lambda/function.zip"
  source_file = "${path.module}/../src/transform_lambda.py"
}

data "archive_file" "load_lambda" {
  type        = "zip"
  output_path = "${path.module}/../packages/load_lambda/function.zip"
  source_file = "${path.module}/../src/load_lambda.py"
}

# Define extract lambda function
resource "aws_lambda_function" "extract_lambda" {
  function_name = var.extract_lambda
  role          = aws_iam_role.lambda_role.arn
  description = "Extraction"
  s3_bucket = aws_s3_object.lambda_code[var.extract_lambda].bucket
  s3_key    = aws_s3_object.lambda_code[var.extract_lambda].key

  runtime = var.python_runtime
  handler = "${var.extract_lambda}.lambda_handler"
  timeout = 70

  source_code_hash = filebase64sha256("${path.module}/../packages/${var.extract_lambda}/function.zip")

  layers = [
    aws_lambda_layer_version.db_layer.arn, aws_lambda_layer_version.utils_layer.arn
  ]
  depends_on = [aws_s3_object.lambda_code, aws_s3_object.db_layer_object, aws_s3_object.utils_layer_object]
  environment {
    variables = {
      PG_HOST     = var.pg_host
      PG_PORT     = var.pg_port
      PG_USER     = var.pg_user
      PG_PASSWORD = var.pg_password
      PG_DATABASE = var.pg_database
    }
}
}


# define transform lambda
resource "aws_lambda_function" "transform_lambda" {
  function_name = var.transform_lambda
  role          = aws_iam_role.lambda_role.arn

  s3_bucket = aws_s3_object.lambda_code[var.transform_lambda].bucket
  s3_key    = aws_s3_object.lambda_code[var.transform_lambda].key

  runtime = var.python_runtime
  handler = "${var.transform_lambda}.lambda_handler"
  timeout = 120

  source_code_hash = filebase64sha256("${path.module}/../packages/${var.transform_lambda}/function.zip")

  layers = [
    "arn:aws:lambda:eu-west-2:336392948345:layer:AWSSDKPandas-Python313:2", aws_lambda_layer_version.utils_layer.arn
  ]
  depends_on = [aws_s3_object.lambda_code, aws_s3_object.utils_layer_object]
}



# define load lambda
resource "aws_lambda_function" "load_lambda" {
  function_name = var.load_lambda
  role          = aws_iam_role.lambda_role.arn

  s3_bucket = aws_s3_object.lambda_code[var.load_lambda].bucket
  s3_key    = aws_s3_object.lambda_code[var.load_lambda].key

  runtime = var.python_runtime
  handler = "${var.load_lambda}.lambda_handler"
  timeout = 120

  source_code_hash = filebase64sha256("${path.module}/../packages/${var.load_lambda}/function.zip")

  layers = [
    aws_lambda_layer_version.db_layer.arn, "arn:aws:lambda:eu-west-2:336392948345:layer:AWSSDKPandas-Python313:2", aws_lambda_layer_version.utils_layer.arn
  ]
  depends_on = [aws_s3_object.lambda_code, aws_s3_object.utils_layer_object, aws_s3_object.db_layer_object]
  environment {
      variables = {
        PG_HOST     = var.dw_host
        PG_PORT     = var.pg_port
        PG_USER     = var.pg_user
        PG_PASSWORD = var.dw_password
        PG_DATABASE = var.dw_database
      }
}
}





