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

Links
- Architecture diagram: ./architecture.md
- Conversation summary: ./conversation-summary.md