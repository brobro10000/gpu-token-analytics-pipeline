# gpu-token-analytics-pipeline
Analytics pipeline and course artifacts for GPU &amp; token-usage experiments—assignments, diagrams, and reports for CS5287.

## Course Assignments Overview

This repository contains documentation and artifacts for CS5287 course assignments (CA0–CA4), demonstrating the evolution of a GPU token analytics pipeline from manual deployment to enterprise-scale multi-site architecture.

**Core Pipeline**: Producers → Kafka → Processor → MongoDB  
**Use Case**: Track GPU metrics and token throughput; compute cost_per_token and store analytics data.

### Assignment Progression

- **[CA0 — Manual Deployment on 4 VMs](./docs/assignments/CA0/README.md)**  
  Manual provisioning, SSH hardening, basic pipeline validation

- **[CA1 — IaC Rebuild (Same Topology, Automated)](./docs/assignments/CA1/README.md)**  
  Infrastructure as Code with Terraform/Ansible, idempotent deployment

- **[CA2 — Orchestrated (Kubernetes/Swarm)](./docs/assignments/CA2/README.md)**  
  Container orchestration with StatefulSets, Deployments, and Services

- **[CA3 — Cloud-Native Ops](./docs/assignments/CA3/README.md)**  
  Observability, autoscaling, security policies, and resilience testing

- **[CA4 — Multi-Site Connectivity & Advanced Networking](./docs/assignments/CA4/README.md)**  
  Service mesh, cross-region replication, and disaster recovery

Each assignment includes architecture diagrams (PlantUML), replication steps, and conversation summaries documenting decisions and tradeoffs.
