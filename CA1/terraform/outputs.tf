# --- Data sources for account and region ---
data "aws_caller_identity" "me" {}

data "aws_region" "current" {}

# --- Metadata outputs ---
output "account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.me.account_id
}

output "arn" {
  description = "ARN of the current caller identity"
  value       = data.aws_caller_identity.me.arn
}

output "region" {
  description = "AWS region in use"
  value       = data.aws_region.current.name
}

# --- Networking outputs ---
output "vpc_id" {
  description = "VPC ID created by the VPC module"
  value       = module.network.vpc_id
}

output "subnet_id" {
  description = "Subnet ID created by the VPC module"
  value       = module.network.subnet_id
}

output "security_groups" {
  description = "Security group IDs created by the security_groups module"
  value       = module.security_groups.sg_ids
}

# --- Instance outputs ---
output "instance_private_ips" {
  description = "Private IPs of all CA1 instances"
  value       = module.instances.private_ips
}

output "instance_public_ips" {
  description = "Public IPs of all CA1 instances (null if none assigned)"
  value       = module.instances.public_ips
}
