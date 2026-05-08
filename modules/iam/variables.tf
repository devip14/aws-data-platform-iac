variable "role_name" {
  type = string
}

variable "role_path" {
  type    = string
  default = "/"
}

variable "description" {
  type    = string
  default = ""
}

variable "max_session_duration" {
  type    = number
  default = 3600
}

variable "assume_role_policy" {
  description = "JSON trust policy document"
  type        = string
}

variable "managed_policy_arns" {
  description = "AWS managed or customer-managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "JSON inline policy. Null skips creation."
  type        = string
  default     = null
}

variable "cross_account_policy_json" {
  description = "JSON policy for cross-account role assumptions"
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
