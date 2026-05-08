variable "function_name" { type = string }
variable "description"   { type = string; default = "" }
variable "runtime"       { type = string; default = "python3.12" }
variable "handler"       { type = string; default = "lambda_function.lambda_handler" }
variable "filename"      { type = string }
variable "timeout"       { type = number; default = 300 }
variable "memory_size"   { type = number; default = 256 }
variable "environment_variables" { type = map(string); default = {} }
variable "subnet_ids"           { type = list(string); default = null }
variable "security_group_ids"   { type = list(string); default = null }
variable "log_retention_days"   { type = number; default = 30 }
variable "custom_policy_json"   { type = string; default = null }
variable "error_alarm_threshold" { type = number; default = 1 }
variable "alarm_sns_arns"       { type = list(string); default = [] }
variable "tags"                 { type = map(string); default = {} }
