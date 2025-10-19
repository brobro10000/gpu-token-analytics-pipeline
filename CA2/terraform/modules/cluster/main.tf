#############################
# modules/cluster/main.tf
#############################

# Region-aware Ubuntu 24.04 LTS (amd64)
data "aws_ssm_parameter" "ubuntu_24_04_amd64" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

#########################
# Control-plane instance
#########################
resource "aws_instance" "control_plane" {
  ami                         = data.aws_ssm_parameter.ubuntu_24_04_amd64.value
  instance_type               = var.control_instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.sg_ids.admin, var.sg_ids.k8s_nodes]
  key_name                    = var.key_name
  associate_public_ip_address = var.public_ip

  # cloud-init: install k3s server and make kubeconfig world-readable (mode 644)
  user_data = templatefile("${path.module}/templates/control-plane.cloudinit.tftpl", {})

  # keep parity with CA1
  user_data_replace_on_change = true

  # root disk settings (from variables.tf)
  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = var.root_volume_type
    delete_on_termination = true
  }

  tags = merge(var.tags, { Project = var.name, Name = "${var.name}-k3s-control-plane", Role = "k3s-control-plane" })
}

#############
# Workers
#############
resource "aws_instance" "worker" {
  count                       = var.worker_count
  ami                         = data.aws_ssm_parameter.ubuntu_24_04_amd64.value
  instance_type               = var.worker_instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = compact([lookup(var.sg_ids, "k8s_nodes", null), lookup(var.sg_ids, "admin", null)])
  key_name                    = var.key_name
  associate_public_ip_address = var.public_ip

  # cloud-init joins using the control plane's private IP
  user_data = templatefile("${path.module}/templates/worker.cloudinit.tftpl", {
    CONTROL_PLANE_IP = aws_instance.control_plane.private_ip
  })

  user_data_replace_on_change = true

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = var.root_volume_type
    delete_on_termination = true
  }

  tags = merge(var.tags, { Project = var.name, Name = "${var.name}-k3s-worker-${count.index}", Role = "k3s-worker" })

  depends_on = [aws_instance.control_plane]
}
