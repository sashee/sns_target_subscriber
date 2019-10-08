provider "aws" {
}

resource "random_id" "id" {
  byte_length = 8
}

module "sns_lambda_1" {
	source = "./modules/sns_consumer"

	name = "lambda_1"
	table_arn = aws_dynamodb_table.messages.arn
	topic_arn = aws_sns_topic.topic.arn
}

module "sns_lambda_2" {
	source = "./modules/sns_consumer"

	name = "lambda_2"
	table_arn = aws_dynamodb_table.messages.arn
	topic_arn = aws_sns_topic.topic.arn
}

resource "aws_sns_topic" "topic" {
}

resource "aws_sns_topic_subscription" "subscription_1" {
  topic_arn = aws_sns_topic.topic.arn
  protocol  = "lambda"
  endpoint  = module.sns_lambda_1.arn
	filter_policy = jsonencode(map("target",list("lambda_1", "all")))
}

resource "aws_sns_topic_subscription" "subscription_2" {
  topic_arn = aws_sns_topic.topic.arn
  protocol  = "lambda"
  endpoint  = module.sns_lambda_2.arn
	filter_policy = jsonencode(map("target",list("lambda_2", "all")))
}

resource "aws_dynamodb_table" "messages" {
  name           = "${random_id.id.hex}-messages-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "name"
  range_key      = "timestamp"

  attribute {
    name = "name"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }
}

module "fe_lambda" {
	source = "./modules/fe"

	table_arn = aws_dynamodb_table.messages.arn
	topic_arn = aws_sns_topic.topic.arn
}

output "url" {
	value = module.fe_lambda.url
}
