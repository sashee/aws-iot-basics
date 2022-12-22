data "archive_file" "lambda" {
  type        = "zip"
  output_path = "/tmp/lambda_${random_id.id.hex}.zip"
  source {
    content  = <<EOF
import { IoTDataPlaneClient, UpdateThingShadowCommand } from "@aws-sdk/client-iot-data-plane";

export const handler = async (event) => {
	console.log(JSON.stringify(event, undefined, 4));
	const {thingName, shadowName, current} = event;
	return new IoTDataPlaneClient().send(new UpdateThingShadowCommand({
		shadowName,
		thingName,
		payload: Buffer.from(JSON.stringify({
			state: {
				desired: {
					value: "Echo: " + current.state.reported.value,
				}
			}
		}))
	}));
};
EOF
    filename = "main.mjs"
  }
}

resource "aws_lambda_function" "lambda" {
  function_name = "${random_id.id.hex}-lambda"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  handler = "main.handler"
  runtime = "nodejs18.x"
  role    = aws_iam_role.lambda_exec.arn
}

resource "aws_cloudwatch_log_group" "loggroup_inline" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 14
}

data "aws_iam_policy_document" "lambda_exec_role_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
  statement {
    actions = [
      "iot:UpdateThingShadow",
    ]
    resources = [
      "${aws_iot_thing.thing.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_exec_role" {
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_exec_role_policy.json
}

resource "aws_iam_role" "lambda_exec" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_lambda_permission" "rule" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "iot.amazonaws.com"
  source_arn = aws_iot_topic_rule.rule.arn
}

resource "aws_iot_topic_rule" "rule" {
  name        = "test_${random_id.id.hex}"
  enabled     = true
  sql         = "SELECT current, topic(3) as thingName, topic(6) as shadowName FROM '$aws/things/+/shadow/name/+/update/documents' WHERE isNull(previous) OR previous.state.reported.value <> current.state.reported.value"
  sql_version = "2016-03-23"

	lambda {
		function_arn = aws_lambda_function.lambda.arn
	}
}

