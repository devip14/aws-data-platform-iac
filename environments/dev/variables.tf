variable "aws_region"   { type = string; default = "us-east-1" }
variable "environment"  { type = string; default = "dev" }
variable "project"      { type = string; default = "data-platform" }
variable "use_localstack" { type = bool; default = true }

variable "subnet_id"    { type = string; default = "subnet-00000000" }
variable "master_sg_id" { type = string; default = "sg-00000000" }
variable "slave_sg_id"  { type = string; default = "sg-00000000" }

variable "emr_master_instance_type" { type = string; default = "m5.xlarge" }
variable "emr_core_instance_type"   { type = string; default = "m5.2xlarge" }
variable "emr_core_instance_count"  { type = number; default = 2 }
