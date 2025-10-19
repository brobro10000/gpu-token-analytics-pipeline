# -----------------------------
# Data sources (fine to keep here)
# -----------------------------
data "aws_caller_identity" "me" {}
data "aws_region" "current" {}

# -----------------------------
# Metadata
# -----------------------------
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

# -----------------------------
# Network
# -----------------------------
output "vpc_id" {
  description = "VPC ID created by the network module"
  value       = module.network.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC IPv4 CIDR"
  value       = module.network.vpc_cidr_block
}

output "public_subnet_id" {
  description = "Public subnet ID used for nodes"
  value       = module.network.subnet_id
}

# (Keep if you still expose a generic subnet_id)
output "subnet_id" {
  description = "Alias to the public subnet (back-compat with CA1)"
  value       = module.network.subnet_id
}

# -----------------------------
# Security Groups
# -----------------------------
output "security_groups" {
  description = "Security group IDs created by the security_groups module"
  value       = module.security_groups.sg_ids
}

output "k8s_nodes_sg_id" {
  description = "Security Group ID used by k3s nodes"
  value       = module.security_groups.k8s_nodes_sg_id
}

# -----------------------------
# Cluster (k3s)
# -----------------------------
output "control_plane_public_ip" {
  description = "Public IP of the control-plane node (scp kubeconfig)"
  value       = module.cluster.control_plane_public_ip
}

output "remote_kubeconfig_path" {
  description = "Path to kubeconfig on the control-plane (k3s default)"
  value       = module.cluster.remote_kubeconfig_path
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = try(module.cluster.worker_private_ips, [])
}

# -----------------------------
# Legacy CA1 instances (safe even if disabled)
# -----------------------------
output "instance_private_ips" {
  description = "Private IPs of all CA1 instances (empty if disabled)"
  value       = try(module.instances[0].private_ips, {})
}

output "instance_public_ips" {
  description = "Public IPs of all CA1 instances (empty if disabled)"
  value       = try(module.instances[0].public_ips, {})
}
