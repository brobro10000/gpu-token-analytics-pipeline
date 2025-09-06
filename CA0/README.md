# CA0 — Manual Deployment on 4 VMs

# Table of Contents

- [CA0 — Manual Deployment on 4 VMs](#ca0--manual-deployment-on-4-vms)
    - [Summary](#summary)
    - [Replication (High-Level)](#replication-high-level)
    - [Config Summary (4 VMs)](#config-summary-4-vms)
    - [Security Notes](#security-notes)
    - [Links](#links)

- [Local Development Guide (CA0)](#local-development-guide-ca0)
    - [1. Prerequisites](#1-prerequisites)
    - [2. Running the pipeline](#2-running-the-pipeline)
    - [3. Cleanup & Garbage Collection](#3-cleanup--garbage-collection)
    - [4. Expected](#4-expected)
    - [5. Config Summary (local)](#5-config-summary-local)

- [AWS Deployment (CA0) — 4 VMs, no Docker](#aws-deployment-ca0--4-vms-no-docker)
    - [0. Prerequisites (on your laptop)](#0-prerequisites-on-your-laptop)
    - [1. Create the VPC & Subnet (cost-0)](#1-create-the-vpc--subnet-cost0)
    - [2. Security Groups (ingress least-privilege)](#2-security-groups-ingress-least-privilege)
    - [3. Launch 4 EC2 Instances (keep-them-small)](#3-launch-4-ec2-instances-keep-them-small)
    - [4. Baseline OS hardening (each VM)](#4-baseline-os-hardening-each-vm)
    - [5. Install & configure directly on the VMs](#5-install--configure-directly-on-the-vms)
    - [6. Wire-up (env values used by the Make targets)](#6-wire-up-env-values-used-by-the-make-targets)
    - [7. Connectivity checks (quick smoke)](#7-connectivity-checks-quick-smoke)
    - [8. Functional validation (end-to-end)](#8-functional-validation-end-to-end)
    - [9. Troubleshooting playbook](#9-troubleshooting-playbook)
    - [10. Cost control & teardown](#10-cost-control--teardown)
    - [11. What to capture for submission](#11-what-to-capture-for-submission)
    - [Command quick-ref](#command-quick-ref)


### Summary
- Pipeline: Producers → Kafka → Processor → MongoDB.
- Use case: Track GPU metrics and token throughput; compute cost_per_token and store in MongoDB (collections: gpu_metrics, token_usage).
- Security: SSH key-only; minimal open ports.

### Replication (High-Level)
1) Provision 4 VMs (≈2 vCPU/4GB) in one subnet.
2) Harden SSH (PasswordAuthentication no; PermitRootLogin no); enable ufw to mirror SG rules.
3) VM1: Install Kafka 3.x (+ ZooKeeper or KRaft). Create topic tokens.
4) VM2: Install MongoDB 7.x; create database ca0.
5) VM3: Install Docker; run processor container with env:
   - KAFKA_BOOTSTRAP (e.g., VM1:9092), KAFKA_TOPIC=tokens
   - MONGODB_URI (mongodb://VM2:27017/ca0)
   - PRICE_PER_HOUR_USD, GPU_METRICS_SOURCE=nvml|nvidia-smi|seed
6) VM4: Install Docker; run 1–2 producer containers to publish token events.
7) Validate end-to-end and capture logs/screenshots.


### Config Summary (4 VMs)

| VM   | Component  | Version                           | Host/IP:Port      | Notes                                      |
|------|------------|-----------------------------------|-------------------|--------------------------------------------|
| VM1  | Kafka      | 3.7.0 (Scala 2.13, KRaft)         | 10.0.1.10:9092    | Topics: `gpu.metrics.v1`, `token.usage.v1` |
| VM2  | MongoDB    | 7.0.x                             | 10.0.1.11:27017   | Database: `ca0` with `gpu_metrics`, `token_usage` |
| VM3  | Processor  | FastAPI 0.112 / Uvicorn 0.30      | 10.0.1.12:8080    | Env: `PRICE_PER_HOUR_USD=0.85`; consumes Kafka, writes Mongo |
| VM4  | Producers  | Python 3.12 + confluent-kafka 2.5 | 10.0.1.13 → VM1   | Emits GPU metrics + token usage messages   |

### Security Notes:
- SSH key-only access on all VMs (`PasswordAuthentication no`).
- UFW mirrors SGs:
    - VM1: allow 9092 from VM3 + VM4 only.
    - VM2: allow 27017 from VM3 only.
    - VM3: allow 8080 from Admin IP only.
    - VM4: no inbound except SSH.

### Links
- Architecture diagram: [./architecture.md](./docs/architecture.md)
- Conversation summary: [./conversation-summary.md](./docs/conversation-summary.md)

# Local Development Guide (CA0)

This guide explains how to test the **Kafka → Processor → Producer → MongoDB** pipeline locally on your laptop.  
⚠️ For **CA0 submission** you must deploy into **4 separate VMs** with Docker Compose. This doc is **dev-only**.

---

## 1. Prerequisites

- **MongoDB 7.x** running locally
    - macOS:
      ```bash
      brew tap mongodb/brew
      brew install mongodb-community@7.0
      brew services start mongodb-community@7.0
      ```
    - Ubuntu: [Install MongoDB 7.x](https://www.mongodb.com/docs/v7.0/tutorial/install-mongodb-on-ubuntu/)

- **Java (for Kafka)**:  
  macOS: `brew install openjdk@17`  
  Ubuntu: `sudo apt-get install -y default-jre`

- **Python 3.12+** with `venv`

---

## 2. Running the pipeline

From inside `CS5287/CA0/`:

### Step 1 — Start Kafka (KRaft)
```bash
make kafka-download    # download Kafka 3.7.0
make kafka-start       # format storage + start broker
make topics-create     # create gpu.metrics.v1 + token.usage.v1
```

### Step 2 — Run the processor
```bash
make processor-venv
make processor-run     # serves FastAPI on http://localhost:8080
```

### Step 3 — Run the producer
```bash
make producer-venv
make producer-run      # emits ~20 test messages
```

### Step 4 — Verify everything
```bash
make mongo-counts      # show docs in gpu_metrics and token_usage
make health            # GET /health from processor
make status            # Kafka status + counts + health
```

---

### 3. Cleanup & Garbage Collection
Stop and clean services when finished:
```bash
make down        # stop Kafka
make clean       # stop Kafka + clear Python venvs/caches (keeps Mongo data)
make gc          # clean + remove Kafka tarball + extracted dir (keeps Mongo data)
make really-gc   # aggressive cleanup: gc + remove *.pyc
```
If Kafka fails with a cluster.id mismatch, reset its data:
```bash
make kafka-reset   # wipes local Kafka logs in .kafka-data
make kafka-start   # reformat + restart
make topics-create
```
Database cleanup
```bash
make db-clear      # drop ONLY collections gpu_metrics + token_usage in DB 'ca0'
make db-drop       # drop the ENTIRE 'ca0' database
make purge         # really-gc + db-drop (nuclear: wipes code artifacts AND DB)
```

---

### 4. Expected 
- `make mongo-counts` should show:
```bash
20
{ 
  _id: ObjectId(...), 
  ts: "...", 
  model: "llama-3-70b", 
  ..., 
  cost_per_token: ... 
}
```
- `make health` should return:
```bash
{"status":"ok"}
```

---

### 5. Config Summary (local)

| Component | Version                           | Host/Port         | Notes                                    |
| --------- | --------------------------------- | ----------------- | ---------------------------------------- |
| Kafka     | 3.7.0 (Scala 2.13)                | localhost:9092    | KRaft mode, topics pre-created           |
| MongoDB   | 7.0.x                             | localhost:27017   | Database: `ca0`                          |
| Processor | FastAPI 0.112 / Uvicorn 0.30      | localhost:8080    | Env: `PRICE_PER_HOUR_USD=0.85`           |
| Producer  | Python 3.12 + confluent-kafka 2.5 | localhost → Kafka | Emits `gpu.metrics.v1`, `token.usage.v1` |


---

# AWS Deployment (CA0) — 4 VMs, no Docker

This section explains how to provision **four EC2 instances** in a single VPC/subnet and install everything **directly on the VMs** (no containers), matching the architecture and flow: **Producers → Kafka → Processor → MongoDB**.

> TL;DR: create the network, launch four small instances, lock down SGs, then run the **remote VM** targets from the root `Makefile`: `vm1-setup`, `vm2-setup`, `vm3-setup`, `vm4-setup`, etc.

---

## 0) Prerequisites (on your laptop)

* SSH key able to reach your EC2 instances (e.g., `~/.ssh/ca0.pem`).
* The merged **root `Makefile`** already in `CA0/`.
* Export your VM connection details (private IPs from your diagram):

  ```bash
  export SSH_USER=ubuntu
  export SSH_KEY=~/.ssh/ca0.pem
  export VM1_IP=10.0.1.10  # Kafka
  export VM2_IP=10.0.1.11  # Mongo
  export VM3_IP=10.0.1.12  # Processor
  export VM4_IP=10.0.1.13  # Producers
  ```
* Code folders present:

    * Processor app at `vm3-processor/app/`
    * Producer app at `vm4-producers/`

---

## 1) Create the VPC & Subnet (cost: \$0)

* **VPC**: `10.0.0.0/16`
* **Subnet**: `10.0.1.0/24` (e.g., `us-east-1a`)
* Attach an **Internet Gateway** and add a default route to it for package installs.
* Enable **DNS hostnames** on the VPC.

---

## 2) Security Groups (ingress least-privilege)

Create four SGs and add these **inbound** rules (outbound = allow all):

| Target VM (SG)     |  Port | Source                         | Purpose                  |
| ------------------ | ----: | ------------------------------ | ------------------------ |
| VM1 `sg-kafka`     |  9092 | `sg-processor`, `sg-producers` | Kafka client traffic     |
| VM1 `sg-kafka`     |    22 | **Your Admin IP**              | SSH                      |
| VM2 `sg-mongo`     | 27017 | `sg-processor`                 | DB writes from Processor |
| VM2 `sg-mongo`     |    22 | **Your Admin IP**              | SSH                      |
| VM3 `sg-processor` |  8080 | **Your Admin IP**              | `/health` endpoint       |
| VM3 `sg-processor` |    22 | **Your Admin IP**              | SSH                      |
| VM4 `sg-producers` |    22 | **Your Admin IP**              | SSH                      |

> Optional: mirror these with **UFW** on the hosts for defense-in-depth.

---

## 3) Launch 4 EC2 Instances (keep them small)

| VM  | Role      | Type     | AMI (Ubuntu 22.04 LTS) | Private IP |
| --- | --------- | -------- | ---------------------- | ---------- |
| VM1 | Kafka     | t3.small | 22.04 LTS              | 10.0.1.10  |
| VM2 | MongoDB   | t3.small | 22.04 LTS              | 10.0.1.11  |
| VM3 | Processor | t3.micro | 22.04 LTS              | 10.0.1.12  |
| VM4 | Producers | t3.micro | 22.04 LTS              | 10.0.1.13  |

* Root volume: **8 GB gp3** (default).
* Attach each to the **subnet** above and its **role SG**.
* Associate an **Elastic IP** with VM3 only if you’ll hit `/health` directly from the Internet; otherwise, use a bastion or SSM.

---

## 4) Baseline OS hardening (each VM)

SSH into each VM and run:

```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y unzip curl wget git net-tools htop python3 python3-venv openjdk-17-jre-headless
# SSH hardening
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
# Optional UFW (if you want host firewall)
sudo ufw default deny incoming && sudo ufw default allow outgoing && sudo ufw allow ssh && sudo ufw enable
```

> You can skip manual UFW rules and rely solely on SGs if preferred.

---

## 5) Install & configure **directly on the VMs** (from your laptop)

Run these in **`CA0/` on your laptop** (they use SSH + `scp/rsync` and create `systemd` units):

### VM1 — Kafka (KRaft)

```bash
make vm1-setup     # installs Java + Kafka 3.7.0, writes server.properties (advertises 10.0.1.10)
make vm1-start     # enables & starts kafka.service
make vm1-topics    # creates gpu.metrics.v1 + token.usage.v1
```

### VM2 — MongoDB 7.0

```bash
make vm2-setup     # installs MongoDB 7.0; bind 0.0.0.0
make vm2-start     # enables & starts mongod
```

### VM3 — Processor (FastAPI)

```bash
make vm3-setup     # copies vm3-processor/app/, creates venv, installs deps, writes .env
make vm3-service   # creates processor.service (Uvicorn :8080) and starts it
make vm3-health    # curls http://localhost:8080/health on VM3
```

### VM4 — Producers (Python)

```bash
make vm4-setup     # copies vm4-producers/, creates venv, installs deps, ensures a gpu_seed.json
make vm4-runonce   # runs producer.py once (or:)
make vm4-service   # creates producers.timer to run every minute
```

---

## 6) Wire-up (env values used by the Make targets)

* **Kafka advertised listener**: `PLAINTEXT://10.0.1.10:9092` (set by `vm1-setup`)
* **Processor env** (written to `/opt/processor/.env`):

  ```
  KAFKA_BOOTSTRAP=10.0.1.10:9092
  MONGO_URL=mongodb://10.0.1.11:27017/ca0
  PRICE_PER_HOUR_USD=0.85
  GPU_METRICS_SOURCE=seed
  ```
* **Producer env** (provided to service):
  `KAFKA_BOOTSTRAP=10.0.1.10:9092`, `TOPIC_METRIC=gpu.metrics.v1`, `TOPIC_TOKEN=token.usage.v1`, `GPU_SEED=/opt/producers/data/gpu_seed.json`

---

## 7) Connectivity checks (quick smoke)

From your laptop:

```bash
make ping
```

Under the hood it runs:

* **VM3 → VM1**: TCP `10.0.1.10:9092`
* **VM3 → VM2**: TCP `10.0.1.11:27017`
* **VM4 → VM1**: TCP `10.0.1.10:9092`

If these fail, fix **SGs** and confirm VM1 advertises `10.0.1.10:9092`.

---

## 8) Functional validation (end-to-end)

1. **Kafka topics exist** (on VM1):

   ```bash
   make vm1-topics     # re-runs safely; then lists topics
   ```

2. **Processor healthy** (on VM3):

   ```bash
   make vm3-health     # expect: {"status":"ok"}
   ```

3. **Send events** (on VM4):

   ```bash
   make vm4-runonce    # or rely on vm4-service every minute
   ```

4. **Data landed in Mongo** (on VM2):

   ```bash
   make vm2-stats
   # Expect a positive count in gpu_metrics and a sample from token_usage
   ```

> If counts don’t move:
>
> * Check `make vm3-logs` (processor) and `make vm4-logs` (producers).
> * Re-run `make ping`.
> * Ensure Kafka `advertised.listeners` is `10.0.1.10:9092`.

---

## 9) Troubleshooting playbook

* **Kafka “connection timeout” from VM3/VM4**
  → Wrong SGs or wrong `advertised.listeners`. Fix SGs and ensure VM1 advertises `10.0.1.10:9092`.

* **Kafka cluster-id mismatch**
  → Reformat storage (rare in remote flow, but if needed): stop service, remove `meta.properties`, re-run `vm1-setup` or format with the same cluster id.

* **Mongo not reachable**
  → Ensure VM2 allows port **27017** **from VM3 SG**; check `mongod` status: `make vm2-logs`.

* **Processor can’t connect to Mongo/Kafka**
  → Re-check `/opt/processor/.env`, then `make vm3-restart`.

---

## 10) Cost control & teardown

* **Stop instances** when idle; snapshots (optional) are cheap.
* Keep instance types small (`t3.micro/small`).
* Tag resources: `Course=CS5287, Assignment=CA0, Role=Kafka|Mongo|Processor|Producers`.
* When finished for the day:

    * Stop the systemd services (optional):

      ```bash
      # On each VM
      sudo systemctl stop kafka || true
      sudo systemctl stop mongod || true
      sudo systemctl stop processor || true
      sudo systemctl stop producers.timer || true
      ```
    * **Stop the EC2 instances** in the console.

---

## 11) What to capture for submission

* **Config table** with exact versions & IP\:port (already in this README).
* **Network diagram** (updated if you changed anything).
* **Screenshots**:

    * EC2 instances list with types/SGs
    * Kafka topics list
    * Processor `/health`
    * Mongo counts/one document preview
* **Notes on deviations** (e.g., KRaft vs ZooKeeper).

---

### Command quick-ref

```bash
# VM1 (Kafka)
make vm1-setup && make vm1-start && make vm1-topics && make vm1-logs

# VM2 (Mongo)
make vm2-setup && make vm2-start && make vm2-stats && make vm2-logs

# VM3 (Processor)
make vm3-setup && make vm3-service && make vm3-health && make vm3-logs

# VM4 (Producers)
make vm4-setup && make vm4-runonce   # or: make vm4-service && make vm4-logs

# Connectivity & matrix helper
make ping
make matrix
```

---
