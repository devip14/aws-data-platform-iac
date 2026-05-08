terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Swap endpoint_url for real AWS — remove localstack block entirely
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  # LocalStack configuration — remove this block for real AWS
  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      s3             = "http://localhost:4566"
      emr            = "http://localhost:4566"
      iam            = "http://localhost:4566"
      cloudwatch     = "http://localhost:4566"
      lambda         = "http://localhost:4566"
    }
  }

  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  dynamic "default_tags" {
    for_each = var.use_localstack ? [] : [1]
    content {
      tags = {
        Environment = "dev"
        Project     = "data-platform"
        ManagedBy   = "terraform"
      }
    }
  }
}

module "data_lake_bucket" {
  source      = "../../modules/s3"
  bucket_name = "${var.project}-${var.environment}-data-lake"
  kms_key_arn = var.use_localstack ? null : module.kms_key[0].key_arn

  lifecycle_rules = [
    {
      id      = "raw-data-tiering"
      enabled = true
      prefix  = "raw/"
      transitions = [
        { days = 30,  storage_class = "STANDARD_IA" },
        { days = 90,  storage_class = "GLACIER" },
        { days = 365, storage_class = "DEEP_ARCHIVE" }
      ]
      expiration_days                    = 2555
      noncurrent_version_expiration_days = 90
    }
  ]

  tags = local.common_tags
}

module "emr_logs_bucket" {
  source      = "../../modules/s3"
  bucket_name = "${var.project}-${var.environment}-emr-logs"
  lifecycle_rules = [
    {
      id      = "log-expiry"
      enabled = true
      prefix  = null
      transitions = []
      expiration_days = 90
      noncurrent_version_expiration_days = null
    }
  ]
  tags = local.common_tags
}

module "emr_cluster" {
  source       = "../../modules/emr"
  cluster_name = "${var.project}-${var.environment}-spark"
  log_bucket   = module.emr_logs_bucket.bucket_id
  bootstrap_bucket = module.data_lake_bucket.bucket_id

  master_instance_type = var.emr_master_instance_type
  core_instance_type   = var.emr_core_instance_type
  core_instance_count  = var.emr_core_instance_count

  subnet_id                = var.subnet_id
  master_security_group_id = var.master_sg_id
  slave_security_group_id  = var.slave_sg_id

  alarm_sns_arns = [aws_sns_topic.platform_alerts.arn]
  tags           = local.common_tags
}

module "emr_platform_dashboard" {
  source         = "../../modules/cloudwatch"
  dashboard_name = "${var.project}-${var.environment}-emr-platform"

  alarms = [
    {
      name                = "${var.project}-${var.environment}-ec2-cpu-high"
      description         = "EC2 CPU utilization above 85% for 10 minutes"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 300
      statistic           = "Average"
      threshold           = 85
      alarm_actions       = [aws_sns_topic.platform_alerts.arn]
      ok_actions          = [aws_sns_topic.platform_alerts.arn]
      dimensions          = {}
    }
  ]

  widgets = [
    {
      type   = "metric"
      x      = 0; y = 0; width = 12; height = 6
      properties = {
        title  = "EMR Cluster Health"
        period = 300
        stat   = "Average"
        metrics = [
          ["AWS/ElasticMapReduce", "MRUnhealthyNodes", "JobFlowId", module.emr_cluster.cluster_id]
        ]
      }
    }
  ]

  tags = local.common_tags
}

resource "aws_sns_topic" "platform_alerts" {
  name = "${var.project}-${var.environment}-platform-alerts"
  tags = local.common_tags
}

module "kms_key" {
  count  = var.use_localstack ? 0 : 1
  source = "../../modules/iam"

  role_name          = "${var.project}-${var.environment}-emr-cross-account"
  assume_role_policy = data.aws_iam_policy_document.emr_cross_account.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
  ]
  tags = local.common_tags
}

data "aws_iam_policy_document" "emr_cross_account" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["elasticmapreduce.amazonaws.com"]
    }
  }
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}
