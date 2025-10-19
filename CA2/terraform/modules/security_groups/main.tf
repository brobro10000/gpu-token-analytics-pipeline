locals {
  tags = { Project = var.name }
}

# =========================
# Admin SG (SSH from your IP)
# =========================
resource "aws_security_group" "admin" {
  name        = "${var.name}-admin"
  description = "SSH from admin IP"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "${var.name}-admin" })
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_admin_ip" {
  security_group_id = aws_security_group.admin.id
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "admin_all_out" {
  security_group_id = aws_security_group.admin.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# =========================
# k3s / Kubernetes node SG
# =========================
resource "aws_security_group" "k8s_nodes" {
  name        = "${var.name}-k8s-nodes"
  description = "Kubernetes (k3s) node ports"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "${var.name}-k8s-nodes" })
}

# kube-apiserver (kubectl from your IP)
resource "aws_vpc_security_group_ingress_rule" "k8s_apiserver" {
  security_group_id = aws_security_group.k8s_nodes.id
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
}

resource "aws_vpc_security_group_ingress_rule" "k8s_intra_cluster" {
  security_group_id            = aws_security_group.k8s_nodes.id
  referenced_security_group_id = aws_security_group.k8s_nodes.id
  ip_protocol                  = "-1"
  from_port                    = 0
  to_port                      = 0
}

resource "aws_vpc_security_group_ingress_rule" "api_from_workers" {
  security_group_id            = aws_security_group.k8s_nodes.id
  referenced_security_group_id = aws_security_group.k8s_nodes.id
  ip_protocol                  = "tcp"
  from_port                    = 6443
  to_port                      = 6443
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_admin_sg_to_workers" {
  security_group_id            = aws_security_group.k8s_nodes.id
  referenced_security_group_id = aws_security_group.admin.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

# kubelet (cluster-internal)
resource "aws_vpc_security_group_ingress_rule" "k8s_kubelet" {
  security_group_id = aws_security_group.k8s_nodes.id
  cidr_ipv4         = var.vpc_cidr_block
  ip_protocol       = "tcp"
  from_port         = 10250
  to_port           = 10250
}

# Optional NodePorts (cluster-internal)
resource "aws_vpc_security_group_ingress_rule" "k8s_nodeports" {
  count             = var.enable_nodeports ? 1 : 0
  security_group_id = aws_security_group.k8s_nodes.id
  cidr_ipv4         = var.vpc_cidr_block
  ip_protocol       = "tcp"
  from_port         = 30000
  to_port           = 32767
}

resource "aws_vpc_security_group_egress_rule" "k8s_all_out" {
  security_group_id = aws_security_group.k8s_nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# =========================
# (Optional) CA1 app SGs
# =========================
# Toggle them on only if you still use the CA1 VM pattern.
# They are safe to leave disabled for CA2 (Kubernetes-based) deployments.

# Kafka
resource "aws_security_group" "kafka" {
  count  = var.enable_ca1_sgs ? 1 : 0
  name   = "${var.name}-kafka"
  vpc_id = var.vpc_id
  tags   = merge(local.tags, { Name = "${var.name}-kafka" })
}

# Mongo
resource "aws_security_group" "mongo" {
  count  = var.enable_ca1_sgs ? 1 : 0
  name   = "${var.name}-mongo"
  vpc_id = var.vpc_id
  tags   = merge(local.tags, { Name = "${var.name}-mongo" })
}

# Processor
resource "aws_security_group" "processor" {
  count  = var.enable_ca1_sgs ? 1 : 0
  name   = "${var.name}-processor"
  vpc_id = var.vpc_id
  tags   = merge(local.tags, { Name = "${var.name}-processor" })
}

# Producers
resource "aws_security_group" "producers" {
  count  = var.enable_ca1_sgs ? 1 : 0
  name   = "${var.name}-producers"
  vpc_id = var.vpc_id
  tags   = merge(local.tags, { Name = "${var.name}-producers" })
}

# CA1 app rules (only if enabled)
resource "aws_vpc_security_group_ingress_rule" "kafka_from_processor" {
  count                        = var.enable_ca1_sgs ? 1 : 0
  security_group_id            = aws_security_group.kafka[0].id
  referenced_security_group_id = aws_security_group.processor[0].id
  ip_protocol                  = "tcp"
  from_port                    = 9092
  to_port                      = 9092
}

resource "aws_vpc_security_group_ingress_rule" "kafka_from_producers" {
  count                        = var.enable_ca1_sgs ? 1 : 0
  security_group_id            = aws_security_group.kafka[0].id
  referenced_security_group_id = aws_security_group.producers[0].id
  ip_protocol                  = "tcp"
  from_port                    = 9092
  to_port                      = 9092
}

resource "aws_vpc_security_group_ingress_rule" "mongo_from_processor" {
  count                        = var.enable_ca1_sgs ? 1 : 0
  security_group_id            = aws_security_group.mongo[0].id
  referenced_security_group_id = aws_security_group.processor[0].id
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
}

resource "aws_vpc_security_group_ingress_rule" "processor_health_from_admin_ip" {
  count             = var.enable_ca1_sgs ? 1 : 0
  security_group_id = aws_security_group.processor[0].id
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
}
