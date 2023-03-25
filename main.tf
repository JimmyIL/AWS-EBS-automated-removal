data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  regions    = join(", ", var.regions)
  lambda_zip = var.lambda_zip_name      #zip file from .net packaged lambda.
}

#sns topic resources
resource "aws_sns_topic" "remove_ebs_topic" {
  name = var.ebs_sns_name
}

resource "aws_sns_topic_subscription" "remove_ebs_subscription" {
  count     = length(var.ebs_cleanup_email)
  topic_arn = aws_sns_topic.remove_ebs_topic.arn
  protocol  = "email"
  endpoint  = element(var.ebs_cleanup_email, count.index)
}

#lambda function for the ebs volume cleanup automation 
resource "aws_lambda_function" "ebs_volume_cleanup" {
  architectures = [
    "x86_64",
  ]
  filename         = local.lambda_zip
  function_name    = "ebs_volume_cleanup"
  description      = "This function performs ebs automation to remove when conditions are met"
  handler          = "ebs_volume_cleanup::ebs_volume_cleanup.Bootstrap::ExecuteFunction"
  source_code_hash = filebase64sha256("${path.module}/${local.lambda_zip}")
  memory_size      = 512
  package_type     = "Zip"
  role             = aws_iam_role.ebs_volume_removal_lambda.arn
  runtime          = "dotnet6"
  timeout          = 120

  ephemeral_storage {
    size = 512
  }

  tracing_config {
    mode = "PassThrough"
  }

  environment {
    variables = {
      main_region         = var.main_region
      regions             = local.regions
      days                = var.days
      days_until_removed  = var.days_until_removed
      exemption_tag_value = var.exemption_tag_value
      ebs_sns_name        = var.ebs_sns_name
    }
  }
}

#Cloudwatch event configurations for this lambda
resource "aws_cloudwatch_event_rule" "ebs_volume_cleanup" {
  name                = "ebs_volume_cleanup"
  description         = "checks ebs volumes and removes volumes based on metrics and availability"
  schedule_expression = var.scheduled_run
}

resource "aws_cloudwatch_event_target" "ebs_volume_cleanup" {
  rule = aws_cloudwatch_event_rule.ebs_volume_cleanup.name
  arn  = aws_lambda_function.ebs_volume_cleanup.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ebs_volume_cleanup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ebs_volume_cleanup.arn
}
