# gpu-token-analytics-pipeline
Analytics pipeline and course artifacts for GPU &amp; token-usage experiments—assignments, diagrams, and reports for CS5287.

## Course Assignments Overview

This repository contains documentation and artifacts for CS5287 course assignments (CA0–CA4), demonstrating the evolution of a GPU token analytics pipeline from manual deployment to enterprise-scale multi-site architecture.

**Core Pipeline**: Producers → Kafka → Processor → MongoDB  
**Use Case**: Track GPU metrics and token throughput; compute cost_per_token and store analytics data.

## File Structure

```
gpu-token-analytics-pipeline/
├── CA0/
│   ├── README.md                # Documentation, configs, screenshots, demo steps
│   ├── diagrams/
│   │   └── architecture.puml
│   ├── docs/
│   │   ├── architecture.md
│   │   └── conversation-summary.md
│   ├── vm1-kafka/               # VM1 = Kafka broker (pub/sub hub)
│   │   ├── docker-compose.yml   # Runs bitnami/kafka:3.7 in CA0
│   │   ├── configs/
│   │   │   └── server.properties
│   │   └── README.md             # install notes, SG rules, UFW
│   ├── vm2-mongo/               # VM2 = MongoDB
│   │   ├── docker-compose.yml   # Runs mongo:7.0
│   │   ├── configs/
│   │   └── README.md
│   ├── vm3-processor/           # VM3 = FastAPI processor
│   │   ├── docker-compose.yml
│   │   ├── Dockerfile
│   │   ├── app/
│   │   │   ├── main.py
│   │   │   ├── requirements.txt
│   │   │   └── utils/
│   │   └── README.md
│   ├── vm4-producers/           # VM4 = Data producers
│   │   ├── docker-compose.yml
│   │   ├── Dockerfile
│   │   ├── producer.py
│   │   ├── gpu_seed.json
│   │   └── requirements.txt
│   ├── schemas/                 # Shared contracts (same across VMs)
│   │   ├── gpu.metrics.v1.json
│   │   └── token.usage.v1.json
│   └── demo/                    # Evidence scripts
│       └── smoke-test.sh
├── CA1/
│   └── README.md
├── CA2/
│   └── README.md
├── CA3/
│   └── README.md
└── CA4/
    └── README.md
```

### Assignment Progression

- **[CA0 — Manual Deployment on 4 VMs](#ca0-build-and-verify-the-pipeline-by-hand)**  
  Manual provisioning, SSH hardening, basic pipeline validation.

- **[CA1 — IaC Rebuild (Same Topology, Automated)](CA1/README.md)**  
  Infrastructure as Code with Terraform/Ansible, idempotent deployment.

- **[CA2 — Orchestrated (Kubernetes/Swarm)](CA2/README.md)**  
  Container orchestration with StatefulSets, Deployments, and Services.

- **[CA3 — Cloud-Native Ops](CA3/README.md)**  
  Observability, autoscaling, security policies, and resilience testing.

- **[CA4 — Multi-Site Connectivity & Advanced Networking](CA4/README.md)**  
  Service mesh, cross-region replication, and disaster recovery.

Each assignment includes architecture diagrams (PlantUML), replication steps, and conversation summaries documenting decisions and tradeoffs.

---

## CA0 — Build and Verify the Pipeline “by hand”

Goal: Provision 4 VMs, install services, wire data flows, enforce basic security, and document everything end-to-end.

Authoritative references for CA0:
- Architecture and sizing: CA0/docs/architecture.md
- AWS Console setup guide: CA0/aws-vm-setup-instructions.md

### 1) Software Stack (Reference)
- Pub/Sub: Apache Kafka 3.7.0 (KRaft or ZooKeeper local-only)
- Database: MongoDB 7.0
- Processor: Python FastAPI service (Uvicorn), reads NVML/SMI or gpu_seed.json; computes cost_per_token
- Producers: Python (confluent-kafka)
- Container runtime (where applicable): Docker

Configuration Summary (components, versions, hosts, ports):

| Component | Image/Version | Host (VM) | Listen/Target Port |
|---|---|---|---|
| Kafka | bitnami/kafka:3.7 (or native 3.7.0) | VM1 | 9092 |
| MongoDB | mongo:7.0 | VM2 | 27017 |
| Processor | FastAPI (Python 3.12) | VM3 | 8080 (optional) |
| Producers | Python + confluent-kafka 2.5 | VM4 | → VM1:9092 |

See also: CA0/docs/architecture.md for logical and hardware diagrams and port mappings.

### 2) Environment Provisioning (AWS example)
- Cloud: AWS, single VPC with one public subnet (10.0.1.0/24)
- 4 EC2 instances (≈2 vCPU, 4 GB RAM recommended for Kafka/Mongo)
- Record VM names, private IPs, and SG assignments (examples in CA0/aws-vm-setup-instructions.md)

Key console milestones (screenshots):
- SSH Keypair
  
  ![Generate SSH keypair](CA0/screenshots/generateSSH-1.png)
  
  ![Upload SSH keypair](CA0/screenshots/uploadSSHKeypairs-2.png)
  
  ![Successful SSH key upload](CA0/screenshots/successfulSSHUpload-3.png)
- Networking
  
  ![VPC Created](CA0/screenshots/VPCCreated-4.png)
  
  ![Subnet Created](CA0/screenshots/SubnetCreated-5.png)
  
  ![Create and Attach Internet Gateway](CA0/screenshots/CreateAndAttachGateway-6.png)
  
  ![Update Route Table](CA0/screenshots/UpdateRouteTable-7.png)
  
  ![Create Security Groups](CA0/screenshots/CreateSecurityGroups-8.png)
- Instances
  
  ![Create Kafka Instance](CA0/screenshots/CreateKafkaInstance-9.png)
  
  ![SSH Into Kafka](CA0/screenshots/SSHIntoKafka-10.png)
  
  ![Create Remaining Instances](CA0/screenshots/CreateRemainingInstances-11.png)

### 3) Software Installation & Configuration
- VM1 Kafka: install and expose 9092 to private subnet; create topic tokens (12 partitions)
  
  ![Kafka container running on VM1](CA0/screenshots/ProvisionAndStartKafkaContainerInVM-12.png)
- VM2 MongoDB: install 7.0; bind to private IP; expose 27017 to Processor only
  
  ![MongoDB container running on VM2](CA0/screenshots/ProvisionAndStartMongoContainerInVM-13.png)
- VM3 Processor: run the processor container; env vars:
  - KAFKA_BOOTSTRAP=VM1_PRIVATE_IP:9092
  - KAFKA_TOPIC=tokens
  - MONGODB_URI=mongodb://VM2_PRIVATE_IP:27017/ca0
  - PRICE_PER_HOUR_USD=0.85 (example)
  - GPU_METRICS_SOURCE=nvml|nvidia-smi|seed
  
  ![Processor container running on VM3](CA0/screenshots/ProvisionAndStartProcessorContainerInVM-14.png)
- VM4 Producers: run 1–2 producer containers to publish messages
  
  ![Producer container running on VM4](CA0/screenshots/ProvisionAndStartProducerContainer-15.png)

### 4) Data Pipeline Wiring & Verification
- Create Kafka topic tokens with 12 partitions
- Start producers → verify messages in Kafka
- Start processor → consumer group assigns partitions; processor writes to MongoDB (collections: gpu_metrics, token_usage)
- Push sample messages and verify DB entries exist
  
  ![Seed and send metadata via producer](CA0/screenshots/SeedAndSendMetadataViaProducer-16.png)
  
  ![Kafka logs with topics and partitions](CA0/screenshots/KafkaLogsTopicsCreatedWithPartitions-17.png)

### 5) Security Hardening
- Disable password login; SSH key-only (PasswordAuthentication no)
- Security Groups (SG):
  - Kafka (VM1): allow 9092 from Processor (VM3) and Producers (VM4) only
  - MongoDB (VM2): allow 27017 from Processor (VM3) only
  - Processor (VM3): 8080 from Admin IP only (optional)
- On-box UFW to mirror SGs
- Run containers as non-root where supported

### 6) Deliverables Checklist (what to include in CA0)
- VM specs: size, OS, private IPs (list in README table)
- Image tags and versions used
- High-level step list or commands captured
- Network Diagram: link to CA0/docs/architecture.md (logical + hardware diagrams)
- Configuration Summary table (above)
- Demo Video (1–2 min): run producer, show Kafka topic activity, show processor logs, verify MongoDB record
- Screenshots of milestones (see paths above)
- Any deviations from the reference stack and rationale

### 7) Grading Mapping (how this README satisfies rubric)
- Correctness & Completeness: all four stages installed, wired, and verified
- Security Controls: SSH keys only, minimal ports, non-root containers when possible
- Documentation & Diagrams: this README + CA0/docs/architecture.md
- Demo Quality: concise 1–2 minute recording of e2e flow
- Cloud-Modality: AWS console steps documented with screenshots
- Reproducibility: concrete versions, env vars, and commands

### 8) Reproduction Steps (quickstart)
1. Follow CA0/aws-vm-setup-instructions.md to create VPC, SGs, and 4 VMs; record private IPs.
2. On VM1: install/start Kafka 3.7 and create topic tokens with 12 partitions.
3. On VM2: install/start MongoDB 7.0 and create DB ca0.
4. On VM3: deploy processor container with env vars pointing to VM1/VM2.
5. On VM4: run producer containers to send messages to tokens.
6. Verify end-to-end and capture logs; enforce SSH key-only and UFW rules.

For detailed commands and make targets, also see: CA0/README.md.

---

Notes
- All links and images above use local repository paths to avoid external breakage.
- For full architecture details (ports, autoscaling heuristics, partitioning guidance), read CA0/docs/architecture.md.
