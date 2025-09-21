# CA1 – Terraform + Docker-First Implementation (mirrors CA0 pipeline)

**Goal:** Provision the CA0 topology with Terraform, and bootstrap each VM to run services via **Docker Compose** (matching the CA0 VM guides).

## Parity Targets (from CA0)
- **Kafka 3.7.0 (KRaft)** on **VM1**; topics: `gpu.metrics.v1`, `token.usage.v1`  
- **MongoDB 7.0.x** on **VM2**; DB: `ca0`, collections: `gpu_metrics`, `token_usage`  
- **FastAPI 0.112 + Uvicorn 0.30** on **VM3**; `/health` on `:8080`; ENV includes `PRICE_PER_HOUR_USD=0.85`  
- **Producers** (Python 3.12 + confluent-kafka 2.5) on **VM4**; emit GPU + token events  

## Security Groups (ingress)
- **VM1 kafka**: `9092` from `sg-processor` + `sg-producers`; `22` from Admin IP  
- **VM2 mongo**: `27017` from `sg-processor`; `22` from Admin IP  
- **VM3 processor**: `8080` from Admin IP; `22` from Admin IP  
- **VM4 producers**: `22` from Admin IP  

## Bootstrap Strategy (user-data)
- Install **Docker** and **Compose plugin** on all VMs  
- Checkout/pull the repo folders: `CA0/vm1-kafka`, `vm2-mongo`, `vm3-processor`, `vm4-producers`  
- `docker compose up -d` on each VM  
- Create Kafka topics on VM1  
- Write `.env` for VM3 with:
  ```
  KAFKA_BOOTSTRAP=10.0.1.10:9092
  MONGO_URL=mongodb://10.0.1.11:27017/ca0
  PRICE_PER_HOUR_USD=0.85
  GPU_METRICS_SOURCE=seed
  ```
- Optionally configure a **systemd timer/cron** for VM4 producers

## Minimal Terraform Flow
```bash
terraform init
terraform plan -var="your_ip_cidr=AAA.BBB.CCC.DDD/32" -out=tfplan
terraform apply tfplan
terraform output
curl http://<vm3_private_or_public>:8080/health
# Teardown when done
terraform destroy
```

## Diagrams
- Architecture: `ca1-architecture.puml`
- Provisioning Sequence: `ca1-provisioning-sequence.puml`

## Notes
- If you prefer native installs (no Docker) for Kafka or others, keep ports, topics, and ENV the same; CA1 IaC remains identical.
- Mirror SG intent with UFW on hosts for defense-in-depth.

**Sources informing versions/flow:** CA0 README (versions, topics, envs), AWS VM setup with Docker-Compose, and setup instructions. See course docs for exact steps.
