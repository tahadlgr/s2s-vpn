resource "aws_cloudwatch_metric_alarm" "check_vpn_tunnel" {
  alarm_name                = "check-vpn-tunnel"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = 1
  datapoints_to_alarm       = 1
  metric_name               = "TunnelState"
  namespace                 = "AWS/VPN"
  period                    = 600
  statistic                 = "Maximum"
  threshold                 = 0
  alarm_description         = "This metric monitors s2s vpn states"
  alarm_actions             = [aws_sns_topic.s2s_vpn_check_trigger.arn]
  ok_actions                = [aws_sns_topic.s2s_vpn_check_trigger.arn]
  insufficient_data_actions = [aws_sns_topic.s2s_vpn_check_trigger.arn]
  treat_missing_data        = "breaching"
  actions_enabled           = true
  dimensions = {
    VpnId = aws_vpn_connection.s2s.id
  }
}

resource "aws_sns_topic" "s2s_vpn_check_trigger" {
  name = "s2s-vpn-check-trigger"
}

resource "aws_sns_topic_subscription" "s2s_vpn_check_trigger" {
  topic_arn = aws_sns_topic.s2s_vpn_check_trigger.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.s2s_vpn_check.arn
}

######

resource "aws_lambda_permission" "s2s_vpn_check" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s2s_vpn_check.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.s2s_vpn_check_trigger.arn
}

data "archive_file" "s2s_vpn_check" {
  type        = "zip"
  source_file = "${path.module}/lambda/s2s_vpn_check.py"
  output_path = "s2s_vpn_check.zip"
}

resource "aws_lambda_function" "s2s_vpn_check" {
  filename         = data.archive_file.s2s_vpn_check.output_path
  function_name    = "s2s-vpn-check"
  role             = aws_iam_role.s2s_vpn_check.arn
  handler          = "s2s_vpn_check.lambda_handler"
  source_code_hash = data.archive_file.s2s_vpn_check.output_base64sha256
  runtime          = "python3.11"
  timeout          = 600
  depends_on = [
    aws_cloudwatch_log_group.s2s_vpn_check
  ]
  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

resource "aws_iam_role" "s2s_vpn_check" {
  name               = "s2s-vpn-check-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.s2s_vpn_check_assume_role.json
}

data "aws_iam_policy_document" "s2s_vpn_check_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "s2s_vpn_check_policy" {
  name   = "s2s-vpn-check"
  role   = aws_iam_role.s2s_vpn_check.id
  policy = data.aws_iam_policy_document.s2s_vpn_check_policy_doc.json
}

data "aws_iam_policy_document" "s2s_vpn_check_policy_doc" {

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeVpnConnections",
      "ec2:ReplaceVpnTunnel",
      "iam:ListAccountAliases"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.s2s_vpn_check.arn}:*"]
  }

}

resource "aws_cloudwatch_log_group" "s2s_vpn_check" {
  name              = "/aws/lambda/s2s-vpn-check"
  retention_in_days = 7
}
