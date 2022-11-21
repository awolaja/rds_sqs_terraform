terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}

locals {
  iam_lambda_exec_role_name = "${var.env}LambdaExecRole"
  iam_ec2_role_name         = "${var.env}Ec2Role"
  sns_topic_name            = "${var.env}_monitoring"
  sqs_queue_name            = "${var.env}-info-queue"
}
# SQS Queue
module "rds_sqs" {
  source = "./modules/sqs"
  name   = local.sqs_queue_name
  env    = var.env
}

module "sns_monitoring_topic" {
  source              = "./modules/sns"
  topic_name          = local.sns_topic_name
  notifications_email = var.sns_notifications_email
}

module "rds_lambda" {
  source             = "./modules/lambda"
  env                = var.env
  iam_lambda_role    = module.iam_lambda_exec_role.arn
  name               = "rds-lambda"
  description        = "Creates MS SQL RDS instance"
  folder_path        = "files/lambda/create_rds"
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  runtime            = "python3.9"
  timeout            = 30
  env_vars = {
    REGION             = var.region
    ENV                = var.env
    VPC_ID             = var.vpc_id
    SUBENT_IDS         = join(",", var.subnet_ids)
    SUBNET_GROUP_NAME  = var.db_subnet_group_name
    SECURITY_GROUP_IDS = join(",", var.security_group_ids)
    ACCOUNT_ID         = var.account_number
    DB_INSTANCE_CLASS  = var.db_instance_class
    SQL_ENGINE         = var.sql_engine
    SQL_ENGINE_VERSION = var.sql_engine_version
    AVAILABILITY_ZONE  = var.az
    SNS_TOPIC          = module.sns_monitoring_topic.arn
  }
}

module "ec2_lambda" {
  source             = "./modules/lambda"
  env                = var.env
  iam_lambda_role    = module.iam_lambda_exec_role.arn
  name               = "ec2-lambda"
  description        = "Creates MS SQL Server on EC2"
  folder_path        = "files/lambda/create_ec2"
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  runtime            = "python3.9"
  timeout            = 30
  env_vars = {
    REGION                   = var.region
    ENV                      = var.env
    ACCOUNT_ID               = var.account_number
    AMI_ID                   = var.sqlserver_ami_id
    SUBNET_IDS               = join(",", var.subnet_ids)
    SUBNET_GROUP_NAME        = var.db_subnet_group_name
    SECURITY_GROUP_IDS       = join(",", var.security_group_ids)
    INSTANCE_CLASS           = var.ec2_instance_class
    SQS_QUEUE_URL            = module.rds_sqs.id
    KEYPAIR_NAME             = var.ssh_keypair_name
    IAM_INSTANCE_PROFILE_ARN = module.iam_ec2_role.instance_profile_arn
    SNS_TOPIC                = module.sns_monitoring_topic.arn
  }
}

module "rds_data_lambda" {
  source             = "./modules/lambda"
  env                = var.env
  iam_lambda_role    = module.iam_lambda_exec_role.arn
  name               = "rds-data"
  description        = "Triggers by Cloudwatch Eventbridge rule, send RDS Endpoint value to SQS and SNS"
  folder_path        = "files/lambda/rds_data"
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  runtime            = "python3.9"
  timeout            = 30
  env_vars = {
    REGION        = var.region
    ENV           = var.env
    SNS_TOPIC     = module.sns_monitoring_topic.arn
    SQS_QUEUE_URL = module.rds_sqs.id
  }
}

#Eventbridge rule and target
module "rds_event_rule" {
  source        = "./modules/cw_event"
  name          = "${var.env}CaptureRdsEvents"
  description   = "Capture all RDS events"
  target_arn    = module.rds_data_lambda.arn
  event_pattern = <<EOF
{
  "detail-type": ["RDS DB Instance Event"],
  "source": ["aws.rds"],
  "detail": {
    "EventCategories": ["creation"],
    "SourceArn": [{
      "suffix": "rds-sql-server"
    }]
  }
}
EOF
}

# Lambda permission for Eventbridge rule to trigger
resource "aws_lambda_permission" "rds_data_permission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.rds_data_lambda.name
  principal     = "events.amazonaws.com"
  source_arn    = module.rds_event_rule.arn
}

