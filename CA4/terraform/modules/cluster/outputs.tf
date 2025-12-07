# modules/cluster/outputs.tf
# Actual outputs for the cluster module

output "control_plane_public_ip" {
  description = "Public IP of the control-plane node"
  value       = aws_instance.control_plane.public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of the control-plane node"
  value       = aws_instance.control_plane.private_ip
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes (may contain nulls if public_ip=false)"
  value       = [for w in aws_instance.worker : w.public_ip]
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = [for w in aws_instance.worker : w.private_ip]
}

output "remote_kubeconfig_path" {
  value = "/home/ubuntu/kubeconfig-external.yaml"
}