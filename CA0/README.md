# CA0 — Manual Deployment on 4 VMs

Summary
- Pipeline: Producers → Kafka → Processor → MongoDB.
- Use case: Track GPU metrics and token throughput; compute cost_per_token and store in MongoDB (collections: gpu_metrics, token_usage).
- Security: SSH key-only; minimal open ports.

Replication (High-Level)
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

Security Notes:
- SSH key-only access on all VMs (`PasswordAuthentication no`).
- UFW mirrors SGs:
    - VM1: allow 9092 from VM3 + VM4 only.
    - VM2: allow 27017 from VM3 only.
    - VM3: allow 8080 from Admin IP only.
    - VM4: no inbound except SSH.

Links
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
