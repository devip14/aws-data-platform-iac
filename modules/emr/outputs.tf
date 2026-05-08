output "cluster_id" {
  description = "EMR cluster ID"
  value       = aws_emr_cluster.this.id
}

output "cluster_name" {
  description = "EMR cluster name"
  value       = aws_emr_cluster.this.name
}

output "master_dns" {
  description = "DNS name of the master node"
  value       = aws_emr_cluster.this.master_public_dns
}

output "emr_service_role_arn" {
  description = "ARN of the EMR service IAM role"
  value       = aws_iam_role.emr_service_role.arn
}

output "emr_ec2_role_arn" {
  description = "ARN of the EMR EC2 IAM role"
  value       = aws_iam_role.emr_ec2_role.arn
}
