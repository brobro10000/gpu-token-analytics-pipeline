locals {
  tags = { Project = var.name }
}

# Region-aware Ubuntu 24.04 LTS (amd64) AMI
data "aws_ssm_parameter" "ubuntu_24_04_amd64" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# ===== VM1: Kafka =====
resource "aws_instance" "vm1_kafka" {
  ami                         = data.aws_ssm_parameter.ubuntu_24_04_amd64.value
  instance_type               = var.vm1_instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.sg_ids.admin, var.sg_ids.kafka]
  key_name                    = var.key_name
  associate_public_ip_address = var.public_ip
  user_data                   = templatefile("${path.module}/templates/vm1-kafka.cloudinit.tftpl", {})
  user_data_replace_on_change = true
  tags                        = merge(local.tags, { Name = "${var.name}-vm1-kafka", Role = "kafka" })
}

# ===== VM2: MongoDB =====
resource "aws_instance" "vm2_mongo" {
  ami                         = data.aws_ssm_parameter.ubuntu_24_04_amd64.value
  instance_type               = var.vm2_instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.sg_ids.admin, var.sg_ids.mongo]
  key_name                    = var.key_name
  associate_public_ip_address = var.public_ip
  user_data                   = templatefile("${path.module}/templates/vm2-mongo.cloudinit.tftpl", {})
  user_data_replace_on_change = true
  tags                        = merge(local.tags, { Name = "${var.name}-vm2-mongo", Role = "mongo" })
}

# ===== Resolved endpoints (computed from VM1/VM2 private IPs) =====
locals {
  kafka_bootstrap_resolved = "${aws_instance.vm1_kafka.private_ip}:9092"
  mongo_url_resolved       = "mongodb://${aws_instance.vm2_mongo.private_ip}:27017/ca1"

  processor_env = {
    PRICE_PER_HOUR_USD = var.price_per_hour_usd
    KAFKA_BOOTSTRAP    = local.kafka_bootstrap_resolved
    MONGO_URL          = local.mongo_url_resolved
    # build-from-git
    APP_GIT_URL = "https://github.com/brobro10000/gpu-token-analytics-pipeline.git"
    APP_GIT_REF = "main"
    APP_SUBDIR  = "CA0/vm3-processor"   # <— this is the folder with the Dockerfile
    IMAGE_TAG   = "processor:ca0"       # or processor:${var.app_version}
  }
}

# ===== VM3: Processor =====
resource "aws_instance" "vm3_processor" {
  ami                         = data.aws_ssm_parameter.ubuntu_24_04_amd64.value
  instance_type               = var.vm3_instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.sg_ids.admin, var.sg_ids.processor]
  key_name                    = var.key_name
  associate_public_ip_address = var.public_ip
  user_data                   = templatefile("${path.module}/templates/vm3-processor.cloudinit.tftpl", local.processor_env)
  user_data_replace_on_change = true
  tags                        = merge(local.tags, { Name = "${var.name}-vm3-processor", Role = "processor" })
}

# ===== VM4: Producers =====
resource "aws_instance" "vm4_producers" {
  ami                         = data.aws_ssm_parameter.ubuntu_24_04_amd64.value
  instance_type               = var.vm4_instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.sg_ids.admin, var.sg_ids.producers]
  key_name                    = var.key_name
  associate_public_ip_address = var.public_ip
  user_data = templatefile("${path.module}/templates/vm4-producers.cloudinit.tftpl", {
    KAFKA_BOOTSTRAP = local.kafka_bootstrap_resolved
  })
  user_data_replace_on_change = true
  tags = merge(local.tags, { Name = "${var.name}-vm4-producers", Role = "producers" })
}

# ===== Outputs =====
output "private_ips" {
  value = {
    vm1_kafka     = aws_instance.vm1_kafka.private_ip
    vm2_mongo     = aws_instance.vm2_mongo.private_ip
    vm3_processor = aws_instance.vm3_processor.private_ip
    vm4_producers = aws_instance.vm4_producers.private_ip
  }
}

output "public_ips" {
  value = {
    vm1_kafka     = try(aws_instance.vm1_kafka.public_ip, null)
    vm2_mongo     = try(aws_instance.vm2_mongo.public_ip, null)
    vm3_processor = try(aws_instance.vm3_processor.public_ip, null)
    vm4_producers = try(aws_instance.vm4_producers.public_ip, null)
  }
}
