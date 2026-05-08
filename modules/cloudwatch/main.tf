resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.dashboard_name
  dashboard_body = jsonencode({
    widgets = var.widgets
  })
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = { for alarm in var.alarms : alarm.name => alarm }

  alarm_name          = each.value.name
  alarm_description   = each.value.description
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  alarm_actions       = each.value.alarm_actions
  ok_actions          = each.value.ok_actions
  dimensions          = each.value.dimensions

  tags = var.tags
}

resource "aws_cloudwatch_log_metric_filter" "this" {
  for_each = { for f in var.log_metric_filters : f.name => f }

  name           = each.value.name
  pattern        = each.value.pattern
  log_group_name = each.value.log_group_name

  metric_transformation {
    name      = each.value.metric_name
    namespace = each.value.metric_namespace
    value     = each.value.metric_value
  }
}
