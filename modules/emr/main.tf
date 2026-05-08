resource "aws_emr_cluster" "this" {
  name          = var.cluster_name
  release_label = var.release_label
  applications  = var.applications
  log_uri       = "s3://${var.log_bucket}/emr-logs/${var.cluster_name}/"

  termination_protection            = var.termination_protection
  keep_job_flow_alive_when_no_steps = var.keep_alive

  ec2_attributes {
    subnet_id                         = var.subnet_id
    emr_managed_master_security_group = var.master_security_group_id
    emr_managed_slave_security_group  = var.slave_security_group_id
    instance_profile                  = aws_iam_instance_profile.emr_profile.arn
    key_name                          = var.key_name
  }

  master_instance_group {
    instance_type = var.master_instance_type

    ebs_config {
      size                 = var.master_ebs_size
      type                 = "gp3"
      volumes_per_instance = 1
    }
  }

  core_instance_group {
    instance_type  = var.core_instance_type
    instance_count = var.core_instance_count

    ebs_config {
      size                 = var.core_ebs_size
      type                 = "gp3"
      volumes_per_instance = 1
    }
  }

  bootstrap_action {
    path = "s3://${var.bootstrap_bucket}/bootstrap.sh"
    name = "platform-bootstrap"
    args = var.bootstrap_args
  }

  configurations_json = jsonencode([
    {
      Classification = "spark-defaults"
      Properties = {
        "spark.dynamicAllocation.enabled"          = "true"
        "spark.shuffle.service.enabled"            = "true"
        "spark.sql.adaptive.enabled"               = "true"
        "spark.sql.adaptive.coalescePartitions.enabled" = "true"
      }
    },
    {
      Classification = "yarn-site"
      Properties = {
        "yarn.nodemanager.vmem-check-enabled" = "false"
      }
    }
  ])

  service_role = aws_iam_role.emr_service_role.arn

  tags = merge(var.tags, {
    Module      = "emr"
    ManagedBy   = "terraform"
  })
}

resource "aws_iam_role" "emr_service_role" {
  name               = "${var.cluster_name}-emr-service-role"
  assume_role_policy = data.aws_iam_policy_document.emr_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "emr_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["elasticmapreduce.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "emr_service_policy" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

resource "aws_iam_role" "emr_ec2_role" {
  name               = "${var.cluster_name}-emr-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_instance_profile" "emr_profile" {
  name = "${var.cluster_name}-emr-profile"
  role = aws_iam_role.emr_ec2_role.name
}

resource "aws_iam_role_policy_attachment" "emr_ec2_policy" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

resource "aws_cloudwatch_metric_alarm" "emr_unhealthy_nodes" {
  alarm_name          = "${var.cluster_name}-unhealthy-nodes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MRUnhealthyNodes"
  namespace           = "AWS/ElasticMapReduce"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "EMR cluster has unhealthy nodes"
  alarm_actions       = var.alarm_sns_arns

  dimensions = {
    JobFlowId = aws_emr_cluster.this.id
  }
}
