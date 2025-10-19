locals {
  tags = { Project = var.name }
}

# ---------- Admin SG ----------
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

# ---------- K8s nodes SG (for k3s) ----------
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

# kubelet (cluster-internal)
resource "aws_vpc_security_group_ingress_rule" "k8s_kubelet" {
  security_group_id = aws_security_group.k8s_nodes.id
  cidr_ipv4         = var.vpc_cidr_block
  ip_protocol       = "tcp"
  from_port         = 10250
  to_port           = 10250
}

# Optional: NodePort range (cluster-internal)
resource "aws_vpc_security_group_ingress_rule" "k8s_nodeports" {
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

# ---------- CA1 app SGs (harmless to keep; not used in CA2 path) ----------
resource "aws_security_group" "kafka" {
  name   = "${var.name}-kafka"
  vpc_id = var.vpc_id
  tags   = merge(local.tags, { Name = "${var.name}-kafka" })
}

resource "aws_security_group" "mongo" {
  name   = "${var.name}-mongo"
  vpc_id = var.vpc_id
  tags   = merge(local.tags, { Name = "${var.name}-mongo" })
}

resource "aws_security_group" "processor" {
  name   = "${var.name}-processor"
  vpc_id = var.vpc_id
  tags   = merge(local.tags, { Name = "${var.name}-processor" })
}

resource "aws_security_group" "producers" {
  name   = "${var.name}-producers"
  vpc_id = var.vpc_id
  tags   = merge(local.tags, { Name = "${var.name}-producers" })
}

# Example app rules (from CA1)
resource "aws_vpc_security_group_ingress_rule" "kafka_from_processor" {
  security_group_id            = aws_security_group.kafka.id
  referenced_security_group_id = aws_security_group.processor.id
  ip_protocol                  = "tcp"
  from_port                    = 9092
  to_port                      = 9092
}
resource "aws_vpc_security_group_ingress_rule" "kafka_from_producers" {
  security_group_id            = aws_security_group.kafka.id
  referenced_security_group_id = aws_security_group.producers.id
  ip_protocol                  = "tcp"
  from_port                    = 9092
  to_port                      = 9092
}
resource "aws_vpc_security_group_ingress_rule" "mongo_from_processor" {
  security_group_id            = aws_security_group.mongo.id
  referenced_security_group_id = aws_security_group.processor.id
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
}
resource "aws_vpc_security_group_ingress_rule" "processor_health_from_admin_ip" {
  security_group_id = aws_security_group.processor.id
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
}
