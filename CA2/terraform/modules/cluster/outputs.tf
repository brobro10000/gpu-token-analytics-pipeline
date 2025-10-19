output "control_plane_public_ip" {
  value = aws_instance.control_plane.public_ip
}

output "remote_kubeconfig_path" {
  value = "/etc/rancher/k3s/k3s.yaml"
}

output "worker_private_ips" {
  value = [for w in aws_instance.worker : w.private_ip]
}
