# CA0 — AWS VM Setup & Reproduction Guide

This guide documents how to create **4 AWS EC2 VMs** and deploy the CA0 IoT-style pipeline:  
**Producers → Kafka → Processor → MongoDB.**

---

## 1. Prerequisites

- AWS account with IAM user (with EC2 + VPC permissions).
- Key pair for SSH access (`.pem` file).
- Security group(s) configured to match the rules below.
- Local machine with:
    - awscli configured (`aws configure`)
    - ssh client
---

## 2. Network & VM Provisioning

### VPC & Subnet
- Create a VPC with CIDR 10.0.0.0/16.
- Add a subnet: 10.0.1.0/24 (us-east-1a).

### Security Groups
- sg-kafka (VM1): allow TCP/9092 from sg-processor + sg-producers.
- sg-mongo (VM2): allow TCP/27017 from sg-processor only.
- sg-processor (VM3): allow TCP/8080 from Admin IP only.
- sg-producers (VM4): no inbound except SSH (22).

### EC2 Instances
Provision 4 EC2 VMs (t3.medium ≈ 2 vCPU, 4 GB RAM):

| VM   | Name      | Private IP | SG           | Purpose      |
|------|-----------|------------|--------------|--------------|
| VM1  | kafka     | 10.0.1.10  | sg-kafka     | Kafka broker |
| VM2  | mongodb   | 10.0.1.11  | sg-mongo     | MongoDB      |
| VM3  | processor | 10.0.1.12  | sg-processor | FastAPI svc  |
| VM4  | producers | 10.0.1.13  | sg-producers | Data gen     |

⚠️ Ensure key-only SSH: disable password login after provisioning.

---

## 3. Common Setup (All VMs)

# Update packages
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker + Compose plugin
```bash
sudo apt-get install -y docker.io curl
sudo usermod -aG docker $USER
newgrp docker
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -L https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64 \
-o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Harden SSH
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

---

## 4. VM-Specific Steps

### VM1: Kafka
```bash
git clone https://github.com/<your-username>/gpu-token-analytics-pipeline.git
cd gpu-token-analytics-pipeline/CA0/vm1-kafka
docker compose up -d
```

# Create topics
```bash
docker compose exec -T kafka kafka-topics.sh \
--bootstrap-server 10.0.1.10:9092 --create --topic gpu.metrics.v1 --partitions 1 --replication-factor 1

docker compose exec -T kafka kafka-topics.sh \
--bootstrap-server 10.0.1.10:9092 --create --topic token.usage.v1 --partitions 1 --replication-factor 1
```

### VM2: MongoDB
```bash 
cd gpu-token-analytics-pipeline/CA0/vm2-mongo
docker compose up -d

```

# Optional: create indexes
docker compose exec -T mongo mongosh --eval 'db.getSiblingDB("ca0").gpu_metrics.createIndex({ ts: 1 })'

### VM3: Processor

cd gpu-token-analytics-pipeline/CA0/vm3-processor
docker compose build
docker compose up -d

# Verify health endpoint
curl http://localhost:8080/health

### VM4: Producers

cd gpu-token-analytics-pipeline/CA0/vm4-producers
docker compose build
docker compose up --abort-on-container-exit

---

## 5. Validation

On VM2 (Mongo):
```bash 
docker compose exec -T mongo mongosh --eval 'db.getSiblingDB("ca0").gpu_metrics.countDocuments()'
docker compose exec -T mongo mongosh --eval 'db.getSiblingDB("ca0").token_usage.findOne()'
```

Expected:
- Count ~20 in gpu_metrics.
- One token_usage doc with fields: ts, model, prompt_tokens, completion_tokens, latency_ms, gpu_index, cost_per_token.

---

## 6. Security Checklist

- [x] SSH key-only login (no passwords, no root).
- [x] UFW configured per VM to mirror SG rules.
- [x] Minimal open ports (22, 9092, 27017, 8080).
- [x] Containers run as non-root where supported.

---

## 7. Deliverables to Capture

- Screenshots:
    - AWS console VM creation.
    - Security group rules.
    - docker compose ps per VM.
    - Mongo counts after producer run.
    - Processor /health endpoint output.
- Config table (see README).
- 1–2 minute demo video of end-to-end pipeline.
