resource "random_id" "id" {
  byte_length = 8
}

data "aws_arn" "table" {
  arn = var.table_arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "/tmp/${random_id.id.hex}_sns_lambda.zip"
  source {
    content  =<<EOF
const AWS = require("aws-sdk");

const ddb = new AWS.DynamoDB({region: process.env.TABLE_REGION});

exports.handler = async (event, context) => {
	const message = event.Records[0].Sns.Message;

	return ddb.putItem({
		TableName: process.env.TABLE_NAME,
		Item: {
			name: {S: process.env.NAME},
			timestamp: {N: String(new Date().getTime())},
			message: {S: message},
		}
	}).promise();
};
EOF
    filename = "main.js"
  }
}

resource "aws_lambda_function" "lambda" {
  function_name = "${random_id.id.hex}-function"

  filename         = "${data.archive_file.lambda_zip.output_path}"
  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"

  handler                        = "main.handler"
  runtime                        = "nodejs10.x"
  role                           = "${aws_iam_role.lambda_exec.arn}"
  reserved_concurrent_executions = 4

	environment {
		variables = {
			NAME = var.name
			TABLE_REGION = data.aws_arn.table.region
			TABLE_NAME = replace(data.aws_arn.table.resource, "/^.*?/(.*)$/", "$1")
		}
	}
}

resource "aws_lambda_permission" "with_sns" {
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.lambda.function_name
    principal = "sns.amazonaws.com"
    source_arn = var.topic_arn
}

data "aws_iam_policy_document" "lambda_exec_role_policy" {
  statement {
    sid = "1"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
	statement {
		actions = [
			"dynamodb:PutItem"
		]
		resources = [
			var.table_arn
		]
	}
}

resource "aws_iam_role_policy" "lambda_exec_role" {
  role   = "${aws_iam_role.lambda_exec.id}"
  policy = "${data.aws_iam_policy_document.lambda_exec_role_policy.json}"
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

