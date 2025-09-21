# CA1 – Step‑by‑Step Guide (Terraform + Docker‑First)

This guide turns the CA0 manual topology into repeatable, code‑driven infra with **Terraform** and **cloud‑init** (installing **Docker + Compose** on each VM). It maps exactly to the architecture + sequence PUMLs you finalized.

---

## 0) Prereqs (local)
- Terraform ≥ 1.6: `terraform -version`
- AWS CLI v2 configured (`aws sts get-caller-identity` should work)
- An SSH key in `~/.ssh` (public key path you will pass to Terraform)
- Optional: PlantUML to render diagrams locally

---

## 1) Repo layout (suggested)
```
/ca1
  /terraform
    main.tf
    variables.tf
    outputs.tf
    backend.tf            # optional remote state
    /modules
      /vpc
        main.tf
        variables.tf
      /security_groups
        main.tf
        variables.tf
      /instances
        main.tf
        variables.tf
        /templates
          vm1-kafka.cloudinit.tftpl
          vm2-mongo.cloudinit.tftpl
          vm3-processor.cloudinit.tftpl
          vm4-producers.cloudinit.tftpl
  /diagrams
    architecture-final.puml
    provisioning-sequence-final.puml
  Makefile
  README.md
```

> You can reuse the final PUMLs directly (export PNG/SVG with your preferred PlantUML flow).

---

## 2) Root Terraform (minimal working example)

**`terraform/main.tf`**
```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"
    }
  }
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source     = "./modules/vpc"
  vpc_cidr   = var.vpc_cidr
  subnet_cidr= var.subnet_cidr
  name       = var.project_name
}

module "security_groups" {
  source     = "./modules/security_groups"
  vpc_id     = module.vpc.vpc_id
  my_ip_cidr = var.my_ip_cidr
  name       = var.project_name
}

module "instances" {
  source           = "./modules/instances"
  subnet_id        = module.vpc.subnet_id
  sg_ids           = module.security_groups.sg_ids
  key_name         = var.ssh_key_name
  instance_type    = var.instance_type
  project_name     = var.project_name

  # Per‑VM settings
  price_per_hour_usd = var.price_per_hour_usd
  kafka_bootstrap    = "10.0.1.10:9092"
  mongo_url          = "mongodb://10.0.1.11:27017/ca0"
}
```

**`terraform/variables.tf`**
```hcl
variable "project_name"        { type = string }
variable "region"              { type = string  default = "us-east-1" }
variable "vpc_cidr"            { type = string  default = "10.0.0.0/16" }
variable "subnet_cidr"         { type = string  default = "10.0.1.0/24" }
variable "my_ip_cidr"          { type = string } # e.g., "AAA.BBB.CCC.DDD/32"
variable "ssh_key_name"        { type = string }
variable "instance_type"       { type = string  default = "t3a.medium" }
variable "price_per_hour_usd"  { type = number  default = 0.85 }
```

**`terraform/outputs.tf`**
```hcl
output "vm_ips" {
  value = module.instances.private_ips
}
```

---

## 3) Modules

### 3.1 VPC (single‑subnet private topology)
**`modules/vpc/main.tf`**
```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.name}-vpc" }
}

resource "aws_subnet" "this" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = false
  tags = { Name = "${var.name}-subnet" }
}

output "vpc_id"   { value = aws_vpc.this.id }
output "subnet_id"{ value = aws_subnet.this.id }
```

**`modules/vpc/variables.tf`**
```hcl
variable "vpc_cidr"   { type = string }
variable "subnet_cidr"{ type = string }
variable "name"       { type = string }
```

### 3.2 Security Groups (Kafka, Mongo, Processor, Producers)
**`modules/security_groups/main.tf`**
```hcl
variable "vpc_id"     { type = string }
variable "my_ip_cidr" { type = string }
variable "name"       { type = string }

# Base SSH from your IP to all hosts
resource "aws_security_group" "admin" {
  name        = "${var.name}-admin"
  description = "SSH from admin IP"
  vpc_id      = var.vpc_id

  ingress { from_port = 22 to_port = 22 protocol = "tcp" cidr_blocks = [var.my_ip_cidr] }
  egress  { from_port = 0  to_port = 0  protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "kafka" {
  name        = "${var.name}-kafka"
  description = "Kafka 9092"
  vpc_id      = var.vpc_id

  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "mongo" {
  name        = "${var.name}-mongo"
  description = "Mongo 27017"
  vpc_id      = var.vpc_id

  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "processor" {
  name        = "${var.name}-processor"
  description = "Processor 8080"
  vpc_id      = var.vpc_id

  ingress { from_port = 8080 to_port = 8080 protocol = "tcp" cidr_blocks = [var.my_ip_cidr] }
  egress  { from_port = 0    to_port = 0    protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "producers" {
  name        = "${var.name}-producers"
  description = "Producers"
  vpc_id      = var.vpc_id

  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

# Wire intra‑SG ingress rules
resource "aws_vpc_security_group_ingress_rule" "kafka_from_processor" {
  security_group_id = aws_security_group.kafka.id
  referenced_security_group_id = aws_security_group.processor.id
  ip_protocol = "tcp"
  from_port  = 9092
  to_port    = 9092
}

resource "aws_vpc_security_group_ingress_rule" "kafka_from_producers" {
  security_group_id = aws_security_group.kafka.id
  referenced_security_group_id = aws_security_group.producers.id
  ip_protocol = "tcp"
  from_port  = 9092
  to_port    = 9092
}

resource "aws_vpc_security_group_ingress_rule" "mongo_from_processor" {
  security_group_id = aws_security_group.mongo.id
  referenced_security_group_id = aws_security_group.processor.id
  ip_protocol = "tcp"
  from_port  = 27017
  to_port    = 27017
}

output "sg_ids" {
  value = {
    admin     = aws_security_group.admin.id
    kafka     = aws_security_group.kafka.id
    mongo     = aws_security_group.mongo.id
    processor = aws_security_group.processor.id
    producers = aws_security_group.producers.id
  }
}
```

### 3.3 Instances (cloud‑init drives Docker/Compose per VM)
**`modules/instances/variables.tf`**
```hcl
variable "subnet_id"         { type = string }
variable "sg_ids"            { type = map(string) }
variable "key_name"          { type = string }
variable "instance_type"     { type = string }
variable "project_name"      { type = string }
variable "price_per_hour_usd"{ type = number }
variable "kafka_bootstrap"   { type = string }
variable "mongo_url"         { type = string }
```

**`modules/instances/main.tf`**
```hcl
locals {
  common_tags = { Project = var.project_name }
}

resource "aws_instance" "vm1_kafka" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.sg_ids.admin, var.sg_ids.kafka]
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/templates/vm1-kafka.cloudinit.tftpl", {})
  tags                        = merge(local.common_tags, { Name = "${var.project_name}-vm1-kafka" })
}

resource "aws_instance" "vm2_mongo" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_ids.admin, var.sg_ids.mongo]
  key_name               = var.key_name
  user_data              = templatefile("${path.module}/templates/vm2-mongo.cloudinit.tftpl", {})
  tags                   = merge(local.common_tags, { Name = "${var.project_name}-vm2-mongo" })
}

resource "aws_instance" "vm3_processor" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_ids.admin, var.sg_ids.processor]
  key_name               = var.key_name
  user_data              = templatefile("${path.module}/templates/vm3-processor.cloudinit.tftpl", {
    PRICE_PER_HOUR_USD = var.price_per_hour_usd
    KAFKA_BOOTSTRAP    = var.kafka_bootstrap
    MONGO_URL          = var.mongo_url
  })
  tags                   = merge(local.common_tags, { Name = "${var.project_name}-vm3-processor" })
}

resource "aws_instance" "vm4_producers" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_ids.admin, var.sg_ids.producers]
  key_name               = var.key_name
  user_data              = templatefile("${path.module}/templates/vm4-producers.cloudinit.tftpl", {
    KAFKA_BOOTSTRAP = var.kafka_bootstrap
  })
  tags                   = merge(local.common_tags, { Name = "${var.project_name}-vm4-producers" })
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-24.04-amd64-server-*"]
  }
}

output "private_ips" {
  value = {
    vm1_kafka    = aws_instance.vm1_kafka.private_ip
    vm2_mongo    = aws_instance.vm2_mongo.private_ip
    vm3_processor= aws_instance.vm3_processor.private_ip
    vm4_producers= aws_instance.vm4_producers.private_ip
  }
}
```

---

## 4) Cloud‑init templates (per VM)

> These install Docker/Compose and bring up each service via an inline `docker-compose.yml`. Replace image tags as needed (or swap for your CA0 Compose folders).

**`vm1-kafka.cloudinit.tftpl`**
```yaml
#cloud-config
package_update: true
package_upgrade: false
runcmd:
  - apt-get update -y
  - apt-get install -y docker.io docker-compose-plugin
  - mkdir -p /opt/kafka && cd /opt/kafka
  - cat > docker-compose.yml <<'YML'
version: "3.8"
services:
  kafka:
    image: bitnami/kafka:3.7
    container_name: kafka
    ports: ["9092:9092"]
    environment:
      - KAFKA_ENABLE_KRAFT=yes
      - KAFKA_CFG_NODE_ID=1
      - KAFKA_CFG_PROCESS_ROLES=broker,controller
      - KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@localhost:9093
      - KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093
      - KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://0.0.0.0:9092
      - KAFKA_CFG_INTER_BROKER_LISTENER_NAME=PLAINTEXT
      - KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER
    restart: unless-stopped
YML
  - docker compose up -d
  # Create topics (idempotent)
  - docker exec kafka kafka-topics.sh --create --if-not-exists --topic gpu.metrics.v1 --bootstrap-server localhost:9092
  - docker exec kafka kafka-topics.sh --create --if-not-exists --topic token.usage.v1 --bootstrap-server localhost:9092
```

**`vm2-mongo.cloudinit.tftpl`**
```yaml
#cloud-config
package_update: true
runcmd:
  - apt-get update -y
  - apt-get install -y docker.io docker-compose-plugin
  - mkdir -p /opt/mongo && cd /opt/mongo
  - cat > docker-compose.yml <<'YML'
version: "3.8"
services:
  mongo:
    image: mongo:7
    container_name: mongo
    ports: ["27017:27017"]
    volumes:
      - mongodata:/data/db
    restart: unless-stopped
volumes:
  mongodata: {}
YML
  - docker compose up -d
```

**`vm3-processor.cloudinit.tftpl`**
```yaml
#cloud-config
package_update: true
runcmd:
  - apt-get update -y
  - apt-get install -y docker.io docker-compose-plugin
  - mkdir -p /opt/processor && cd /opt/processor
  - cat > .env <<'ENV'
PRICE_PER_HOUR_USD=${PRICE_PER_HOUR_USD}
KAFKA_BOOTSTRAP=${KAFKA_BOOTSTRAP}
MONGO_URL=${MONGO_URL}
GPU_METRICS_SOURCE=seed
ENV
  - cat > docker-compose.yml <<'YML'
version: "3.8"
services:
  app:
    image: ghcr.io/yourorg/processor:latest
    container_name: processor
    env_file: .env
    ports: ["8080:8080"]
    restart: unless-stopped
YML
  - docker compose up -d
```

**`vm4-producers.cloudinit.tftpl`**
```yaml
#cloud-config
package_update: true
runcmd:
  - apt-get update -y
  - apt-get install -y docker.io docker-compose-plugin
  - mkdir -p /opt/producers && cd /opt/producers
  - cat > .env <<'ENV'
KAFKA_BOOTSTRAP=${KAFKA_BOOTSTRAP}
ENV
  - cat > docker-compose.yml <<'YML'
version: "3.8"
services:
  producers:
    image: ghcr.io/yourorg/producers:latest
    container_name: producers
    env_file: .env
    restart: unless-stopped
YML
  - docker compose up -d
```

---

## 5) Makefile helpers (optional)
**`Makefile`**
```makefile
TF=cd terraform && terraform

deploy:
	$(TF) init
	$(TF) plan -var "project_name=ca1" -var "my_ip_cidr=$$(curl -s ifconfig.me)/32" -out tfplan
	$(TF) apply tfplan

test:
	@echo "Health check (processor)"; \
	PROC_IP=$$($(TF) output -raw vm_ips | jq -r '.vm3_processor'); \
	echo "Processor IP: $$PROC_IP"; \
	curl -s --connect-timeout 3 http://$$PROC_IP:8080/health || true

destroy:
	$(TF) destroy -auto-approve
```

> For private‑only subnets, you’ll run health checks via **SSH port‑forwarding** or a bastion. Adjust SGs/NAT/bastion if you need public reachability.

---

## 6) Apply & Verify
```bash
cd terraform
terraform init
terraform plan -var="project_name=ca1" -var="my_ip_cidr=AAA.BBB.CCC.DDD/32" -out=tfplan
terraform apply tfplan
terraform output
# Kafka topics (on VM1 via SSH + docker)
# Mongo check (on VM2) or from VM3 app logs
# Processor: curl /health (direct, or via SSH tunnel)
```

**Expected runtime flows**
- VM4 → VM1: produce `gpu.metrics.v1`, `token.usage.v1` (9092)
- VM3 → VM1: consume (9092)
- VM3 → VM2: persist to MongoDB (27017)
- Admin → VM3: `/health` (8080)

---

## 7) Troubleshooting
- **Kafka topics missing** → ensure topic create commands ran; re‑run on VM1: `docker exec kafka kafka-topics.sh ...`
- **Processor can’t reach Kafka/Mongo** → verify SG rules and env in `/opt/processor/.env`
- **cloud‑init didn’t run** → check `/var/log/cloud-init-output.log` on each VM
- **Private‑only subnet** → use SSH tunnel or add NAT/bastion as needed

---

## 8) Teardown
```bash
cd terraform
terraform destroy -auto-approve
```

---

## 9) Diagrams
- `/diagrams/architecture-final.puml` → export to PNG/SVG
- `/diagrams/provisioning-sequence-final.puml` → export to PNG/SVG

Keep these in the repo so reviewers can map code ↔ architecture easily.
