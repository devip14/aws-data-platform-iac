output "dashboard_arn" { value = aws_cloudwatch_dashboard.this.dashboard_arn }
output "alarm_arns"    { value = { for k, v in aws_cloudwatch_metric_alarm.this : k => v.arn } }
