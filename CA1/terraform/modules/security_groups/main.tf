locals { tags = { Project = var.name } }

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

# Example app rules (add your full set as before)
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

# egress rules omitted for brevity

output "sg_ids" {
  value = {
    admin     = aws_security_group.admin.id
    kafka     = aws_security_group.kafka.id
    mongo     = aws_security_group.mongo.id
    processor = aws_security_group.processor.id
    producers = aws_security_group.producers.id
  }
}
