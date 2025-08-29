# gpu-token-analytics-pipeline
Analytics pipeline and course artifacts for GPU & token-usage experiments—assignments, diagrams, and reports for CS5287.

## Assignment Index
- CA0 – Manual Deployment on 4 VMs (this PR)
- CA1 – IaC recreation of CA0 (planned)
- CA2 – Orchestrated (Kubernetes/Swarm) (planned)
- CA3 – Cloud-native ops (observability, autoscaling, security) (planned)
- CA4 – Multi-hybrid connectivity and failover (planned)

## CA0 Summary — Manual Deployment on 4 VMs
- Topology: Producers → Kafka (broker) → Processor (consumer) → MongoDB
- GPU use case: Processor reads GPU metrics (NVML/nvidia-smi or seed), aggregates tokens/sec from messages, and computes cost_per_token = price_per_hour_usd / (tokens_per_second * 3600). Results are stored in MongoDB collections gpu_metrics and token_usage.
- Security: SSH key-only, minimal open ports (22 admin; 9092 from processor/producers; 27017 from processor; 8080 optional health), non-root containers.

### Replication Steps (High-Level)
1) Create 4 VMs (≈2 vCPU, 4 GB) in the same subnet.
2) Harden SSH (PasswordAuthentication no; PermitRootLogin no) and enable host firewall (ufw) to mirror security groups.
3) VM1: Install Kafka 3.x (+ ZooKeeper or use KRaft) and configure a topic (e.g., tokens).
4) VM2: Install MongoDB 7.x and create database ca0.
5) VM3: Install Docker and run the processor container (env: KAFKA_BOOTSTRAP, KAFKA_TOPIC=tokens, MONGODB_URI, PRICE_PER_HOUR_USD; GPU_METRICS_SOURCE=nvml|nvidia-smi|seed).
6) VM4: Install Docker and run 1–2 producer containers publishing token events to Kafka.
7) Validate end-to-end: confirm Kafka topic ingestion and MongoDB documents for gpu_metrics and token_usage.

More details and diagrams: see docs/assignments/CA0/architecture.md
