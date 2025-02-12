provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_iam_policy" "stop_start_ec2_policy" {
  name = "StopStartEC2Policy"
  path = "/"
  description = "IAM policy for stop and start EC2 from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Start*",
        "ec2:Stop*",
        "ec2:DescribeInstances*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "stop_start_ec2_role" {
  name = "StopStartEC2Role"

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
}

resource "aws_iam_role_policy_attachment" "lambda_role_policy" {
  role = "${aws_iam_role.stop_start_ec2_role.name}"
  policy_arn = "${aws_iam_policy.stop_start_ec2_policy.arn}"
}

# data "archive_file" "lambda" {
#   type        = "zip"
#   source_file = "ec2_lambda_handler.py"
#   output_path = "ec2_lambda_handler.zip"
# }

resource "aws_lambda_function" "stop_ec2_lambda" {
  filename      = "ec2_lambda_handler.zip"
  function_name = "stopEC2Lambda"
  role          = "${aws_iam_role.stop_start_ec2_role.arn}"
  handler       = "ec2_lambda_handler.stop"

  source_code_hash = "${filebase64sha256("ec2_lambda_handler.zip")}"

  runtime = "python3.7"
  memory_size = "250"
  timeout = "60"
}

resource "aws_cloudwatch_event_rule" "ec2_stop_rule" {
  name        = "StopEC2Instances"
  description = "Stop EC2 nodes at 19:00 from Monday to friday"
  schedule_expression = "cron(0 19 ? * 2-6 *)"
}

resource "aws_cloudwatch_event_target" "ec2_stop_rule_target" {
  rule      = "${aws_cloudwatch_event_rule.ec2_stop_rule.name}"
  arn       = "${aws_lambda_function.stop_ec2_lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_stop" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.stop_ec2_lambda.function_name}"
  principal     = "events.amazonaws.com"
}

resource "aws_lambda_function" "start_ec2_lambda" {
  filename      = "ec2_lambda_handler.zip"
  function_name = "startEC2Lambda"
  role          = "${aws_iam_role.stop_start_ec2_role.arn}"
  handler       = "ec2_lambda_handler.start"

  source_code_hash = "${filebase64sha256("ec2_lambda_handler.zip")}"

  runtime = "python3.7"
  memory_size = "250"
  timeout = "60"
}

resource "aws_cloudwatch_event_rule" "ec2_start_rule" {
  name        = "StartEC2Instances"
  description = "Start EC2 nodes at 6:30 from Monday to friday"
  schedule_expression = "cron(30 6 ? * 2-6 *)"
}

resource "aws_cloudwatch_event_target" "ec2_start_rule_target" {
  rule      = "${aws_cloudwatch_event_rule.ec2_start_rule.name}"
  arn       = "${aws_lambda_function.start_ec2_lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_start" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.start_ec2_lambda.function_name}"
  principal     = "events.amazonaws.com"
}