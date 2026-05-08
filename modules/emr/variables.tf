variable "cluster_name" {
  description = "Name of the EMR cluster"
  type        = string
}

variable "release_label" {
  description = "EMR release label e.g. emr-6.15.0"
  type        = string
  default     = "emr-6.15.0"
}

variable "applications" {
  description = "List of applications to install on the cluster"
  type        = list(string)
  default     = ["Spark", "Hive", "Hadoop", "Livy"]
}

variable "log_bucket" {
  description = "S3 bucket name for EMR logs"
  type        = string
}

variable "bootstrap_bucket" {
  description = "S3 bucket containing bootstrap scripts"
  type        = string
}

variable "bootstrap_args" {
  description = "Arguments to pass to the bootstrap script"
  type        = list(string)
  default     = []
}

variable "subnet_id" {
  description = "Subnet ID for EMR cluster nodes"
  type        = string
}

variable "master_security_group_id" {
  description = "Security group ID for master node"
  type        = string
}

variable "slave_security_group_id" {
  description = "Security group ID for core/task nodes"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = null
}

variable "master_instance_type" {
  description = "EC2 instance type for the master node"
  type        = string
  default     = "m5.xlarge"
}

variable "master_ebs_size" {
  description = "EBS volume size in GB for master node"
  type        = number
  default     = 100
}

variable "core_instance_type" {
  description = "EC2 instance type for core nodes"
  type        = string
  default     = "m5.2xlarge"
}

variable "core_instance_count" {
  description = "Number of core nodes"
  type        = number
  default     = 2
}

variable "core_ebs_size" {
  description = "EBS volume size in GB for core nodes"
  type        = number
  default     = 200
}

variable "termination_protection" {
  description = "Enable termination protection on the cluster"
  type        = bool
  default     = false
}

variable "keep_alive" {
  description = "Keep cluster alive after steps complete"
  type        = bool
  default     = true
}

variable "alarm_sns_arns" {
  description = "SNS topic ARNs for CloudWatch alarm notifications"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
