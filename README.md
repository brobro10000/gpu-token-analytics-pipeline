# gpu-token-analytics-pipeline
Analytics pipeline and course artifacts for GPU &amp; token-usage experiments—assignments, diagrams, and reports for CS5287.

## Course Assignments Overview

This repository contains documentation and artifacts for CS5287 course assignments (CA0–CA4), demonstrating the evolution of a GPU token analytics pipeline from manual deployment to enterprise-scale multi-site architecture.

**Core Pipeline**: Producers → Kafka → Processor → MongoDB  
**Use Case**: Track GPU metrics and token throughput; compute cost_per_token and store analytics data.

## File Structure

```
CS5287/
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
│   │   │   └── init-scripts.js  # optional index creation
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
│   ├── config-summary.md        # Table: component, version, host, port
│   └── demo/                    # Evidence
│       ├── smoke-test.sh
│       ├── screenshots/
│       └── demo.mp4
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

- **[CA0 — Manual Deployment on 4 VMs](CA0/README.md)**  
  Manual provisioning, SSH hardening, basic pipeline validation

- **[CA1 — IaC Rebuild (Same Topology, Automated)](CA1/README.md)**  
  Infrastructure as Code with Terraform/Ansible, idempotent deployment

- **[CA2 — Orchestrated (Kubernetes/Swarm)](CA2/README.md)**  
  Container orchestration with StatefulSets, Deployments, and Services

- **[CA3 — Cloud-Native Ops](CA3/README.md)**  
  Observability, autoscaling, security policies, and resilience testing

- **[CA4 — Multi-Site Connectivity & Advanced Networking](CA4/README.md)**  
  Service mesh, cross-region replication, and disaster recovery

Each assignment includes architecture diagrams (PlantUML), replication steps, and conversation summaries documenting decisions and tradeoffs.
