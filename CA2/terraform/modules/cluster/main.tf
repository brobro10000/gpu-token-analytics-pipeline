data "aws_ssm_parameter" "ubuntu_24_04_amd64" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

locals {
  tags = merge(var.tags, { Role = "k3s" })
}

# Control-plane
resource "aws_instance" "control_plane" {
  ami                         = data.aws_ssm_parameter.ubuntu_24_04_amd64.value
  instance_type               = var.control_instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/control-plane.cloudinit.tftpl", {
    # nothing to substitute yet
  })

  tags = merge(local.tags, { Name = "k3s-control-plane" })
}

# Fetch the node token after control-plane comes up
resource "aws_instance" "worker" {
  count                       = var.worker_count
  ami                         = data.aws_ssm_parameter.ubuntu_24_04_amd64.value
  instance_type               = var.worker_instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/worker.cloudinit.tftpl", {
    CONTROL_PLANE_IP = aws_instance.control_plane.private_ip
    # NOTE: k3s auto-discovers token via /var/lib/rancher/k3s/server/node-token we’ll fetch below;
    # to keep cloud-init simple we’ll use the ip+token approach.
    # We'll pass the token via IMDS after boot using a small bash script in cloud-init.
  })

  tags = merge(local.tags, { Name = "k3s-worker-${count.index}" })

  depends_on = [aws_instance.control_plane]
}
