variable "dashboard_name" { type = string }

variable "widgets" {
  description = "CloudWatch dashboard widget definitions"
  type        = any
  default     = []
}

variable "alarms" {
  description = "List of CloudWatch metric alarm definitions"
  type = list(object({
    name                = string
    description         = string
    comparison_operator = string
    evaluation_periods  = number
    metric_name         = string
    namespace           = string
    period              = number
    statistic           = string
    threshold           = number
    alarm_actions       = list(string)
    ok_actions          = list(string)
    dimensions          = map(string)
  }))
  default = []
}

variable "log_metric_filters" {
  description = "CloudWatch log metric filters"
  type = list(object({
    name             = string
    pattern          = string
    log_group_name   = string
    metric_name      = string
    metric_namespace = string
    metric_value     = string
  }))
  default = []
}

variable "tags" { type = map(string); default = {} }
