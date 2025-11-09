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
│   ├── README.md
│   ├── aws-vm-setup-instructions.md
│   ├── diagrams/
│   │   ├── architecture.puml
│   │   └── hardware-architecture.puml
│   ├── docs/
│   │   ├── architecture.md
│   │   └── conversation-summary.md
│   ├── schemas/
│   │   ├── gpu.metrics.v1.json
│   │   └── token.usage.v1.json
│   ├── screenshots/
│   │   └── ...
│   ├── demo/
│   │   ├── smoke-test.sh
│   │   └── screenshots/
│   ├── vm1-kafka/
│   │   ├── docker-compose.yml
│   │   └── config/
│   ├── vm2-mongo/
│   │   ├── docker-compose.yml
│   │   └── config/
│   │       └── init-scripts/
│   │           └── indexes.js
│   ├── vm3-processor/
│   │   ├── docker-compose.yml
│   │   └── app/
│   │       ├── main.py
│   │       └── utils/
│   └── vm4-producers/
│       ├── docker-compose.yml
│       └── producer.py
├── CA1/
│   ├── README.md
│   ├── CA1-step-by-step-guide.md
│   ├── diagrams/
│   │   └── architecture-final.puml
│   ├── docs/
│   │   └── architecture.md
│   ├── screenshots/
│   ├── terraform/
│   │   ├── Makefile
│   │   ├── providers.tf
│   │   └── modules/
│   │       ├── instances/
│   │       │   └── templates/
│   │       ├── network/
│   │       ├── security_groups/
│   │       └── vpc/
│   └── Makefile
├── CA2/
│   ├── README.md
│   ├── docs/
│   │   └── architecture.md
│   ├── diagrams/
│   ├── screenshots/
│   ├── Makefile
│   ├── k8s/
│   │   ├── platform/
│   │   │   ├── kafka/
│   │   │   │   ├── statefulset.yaml
│   │   │   │   └── svc.yaml
│   │   │   └── mongo/
│   │   │       ├── statefulset.yaml
│   │   │       └── svc.yaml
│   │   └── app/
│   │       ├── processor/
│   │       │   └── deploy.yaml
│   │       └── producers/
│   │           ├── deploy.yaml
│   │           ├── hpa.yaml
│   │           └── config.yaml
│   └── terraform/
│       ├── providers.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── modules/
│           ├── cluster/
│           │   └── templates/
│           ├── instances/
│           │   └── templates/
│           ├── network/
│           ├── security_groups/
│           └── vpc/
├── CA3/
│   ├── README.md
│   ├── docs/
│   │   ├── architecture.md
│   │   ├── SLI.md
│   │   ├── SLA.md
│   │   └── SLO.md
│   ├── diagrams/
│   │   ├── architecture.puml
│   │   └── provisioning-sequence-final.puml
│   ├── screenshots/
│   │   └── ...
│   ├── Makefile
│   ├── k8s/
│   │   ├── platform/
│   │   │   ├── kafka/
│   │   │   └── mongo/
│   │   ├── app/
│   │   │   ├── processor/
│   │   │   └── producers/
│   │   └── monitoring/
│   │       └── service-monitoring/
│   └── terraform/
│       ├── providers.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── modules/
│           ├── cluster/
│           │   └── templates/
│           ├── instances/
│           │   └── templates/
│           ├── network/
│           ├── security_groups/
│           └── vpc/
├── CA4/
│   └── README.md
├── README.md
└── infracost_test.tf
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

## CA1 — IaC Rebuild (Terraform-Based Deployment)

Goal: Recreate CA0’s 4-VM topology using Infrastructure as Code (Terraform + cloud-init) with idempotent provisioning, minimal manual steps, and repeatable teardown.

Authoritative references for CA1:
- CA1 overview: CA1/README.md
- Architecture and sequence diagrams: CA1/docs/architecture.md
- Step-by-step guide: CA1/CA1-step-by-step-guide.md

### 1) Software Stack (Reference)
- Same logical pipeline as CA0: Producers → Kafka → Processor → MongoDB
- Runtime: Docker + Compose installed via cloud-init on each VM
- Topics (typical): gpu.metrics.v1, token.usage.v1

Configuration Summary (components, versions, hosts, ports):

| Component | Image/Version | Host (VM) | Listen/Target Port |
|---|---|---|---|
| Kafka | bitnami/kafka:3.7 (or native 3.7.0) | VM1 | 9092 |
| MongoDB | mongo:7.0 | VM2 | 27017 |
| Processor | FastAPI (Python 3.12) | VM3 | 8080 |
| Producers | Python + confluent-kafka 2.5 | VM4 | → VM1:9092 |

See also: CA1/docs/architecture.md for the IaC-based logical and sequence diagrams.

### 2) Environment Provisioning (Terraform)
Prereqs (local): Terraform ≥ 1.6, AWS CLI v2 configured, existing EC2 key pair, jq, curl.

1. Prepare variables (recommended):
   - Copy CA1/terraform/terraform.tfvars.example to CA1/terraform/terraform.tfvars and set:
     - ssh_key_name = "<your-ec2-keypair-name>"
     - my_ip_cidr   = "x.x.x.x/32" (or let Makefile auto-detect MY_IP_CIDR)
     - Optionally adjust region/profile and CIDRs.

   Example terraform.tfvars (minimal):
   
   ```hcl
   project_name = "ca1"
   aws_profile  = "terraform"
   aws_region   = "us-east-1"
   ssh_key_name = "my-ec2-keypair"
   my_ip_cidr   = "203.0.113.25/32"
   public_subnet = true
   ```

2. Deploy infrastructure:
   
   ```bash
   cd CA1/terraform
   make deploy         # terraform init + plan + apply (auto-injects my_ip_cidr)
   ```

   Screenshot milestones:
   
   - Terraform init
     
     ![tf init](CA1/screenshots/tf-init-01.png)
   
   - Terraform apply
     
     ![tf apply](CA1/screenshots/tf-apply-02.png)
   
   - Terraform outputs
     
     ![tf outputs](CA1/screenshots/tf-output-03.png)

3. Inspect resources:
   - CLI: `make outputs` (VPC/subnet IDs and instance IPs)
   - Console: verify EC2 instances are created and running
     
     ![AWS instances](CA1/screenshots/aws-instances-04.png)
     
     ![Verify instances up](CA1/screenshots/verify-instances-05.png)

Notes:
- The Terraform Makefile honors AWS_PROFILE and AWS_REGION; override as needed.
- Security groups restrict access based on my_ip_cidr; use a bastion or enable public IPs if private-only.

### 3) Software Installation & Configuration (Automated)
- Cloud-init templates (CA1/terraform/modules/instances/templates/) install Docker and run components per VM:
  - vm1-kafka.cloudinit.tftpl → Kafka broker (topics created idempotently if included)
  - vm2-mongo.cloudinit.tftpl → MongoDB 7.0 (with indexes/collections as needed)
  - vm3-processor.cloudinit.tftpl → FastAPI processor (env points to Kafka/Mongo private IPs)
  - vm4-producers.cloudinit.tftpl → Producers sending metrics/usage events
- Private networking is used for service-to-service traffic; ports are limited by SGs.

### 4) Data Pipeline Wiring & Verification
Use the CA1 root Makefile (reads Terraform outputs) to validate services end-to-end.

- cd CA1
- make addrs          # show private/public IPs
- make env            # print KAFKA_BOOTSTRAP / MONGO_URL / PROCESSOR_HEALTH using private IPs
- make verify         # runs verify-kafka, verify-mongo, verify-processor, verify-producers
- make verify-workflow MAX_DOCS=100  # optional, runs an end-to-end smoke with caps

Sample outputs:

```bash
$ make env
export KAFKA_BOOTSTRAP=10.0.1.101:9092
export MONGO_URL=mongodb://10.0.1.102:27017/ca0
export PROCESSOR_HEALTH=http://10.0.1.103:8080/health

$ make verify
>> VM1/Kafka: listing topics ...
__consumer_offsets
gpu.metrics.v1
token.usage.v1
>> VM2/Mongo: ping mongod
{ ok: 1 }
>> VM3/Processor: health check ...
{"status":"ok"}
>> VM4/Producers: recent logs ...
...
```

Verification screenshots:

- Kafka topics list

  ![verify kafka](CA1/screenshots/verify-kafka-08.png)

- Mongo verification (ping/indexes)

  ![verify mongo](CA1/screenshots/verify-mongo-09.png)

- Processor health

  ![verify processor](CA1/screenshots/verify-processor-10.png)

- End-to-end workflow (before/after counts)

  ![verify workflow 1](CA1/screenshots/verify-workflow-06.png)

  ![verify workflow 2](CA1/screenshots/verify-workflow-2-11.png)

Internals:
- Terraform outputs include instance_private_ips and instance_public_ips used by the Makefile.

### 5) Security Hardening
- SSH key-only; Security Groups restrict:
  - 22/tcp to my_ip_cidr
  - 9092/tcp (Kafka) to internal producers/processor only
  - 27017/tcp (Mongo) to processor only
  - 8080/tcp (Processor) optionally to my_ip_cidr for admin/testing
- Containers run with least privilege where supported.

### 6) Deliverables Checklist (what to include in CA1)
- terraform.tfvars (with secrets redacted) and Makefile overrides used
- Terraform plan/apply evidence (tfplan retained, screenshots/logs)
- Terraform outputs and resulting private/public IPs
- Architecture/sequence diagrams: CA1/docs/architecture.md
- Short demo: verify-workflow run showing producer → Kafka → processor → MongoDB writes
- Any deviations from CA0 stack and rationale

### 7) Grading Mapping
- Correctness & Completeness: infra created via IaC, services running, E2E verified
- Security Controls: my_ip_cidr gate, minimal ports, SSH keys only
- Documentation & Diagrams: this README section + CA1/docs/architecture.md + CA1/README.md
- Demo Quality: concise capture of verify/verify-workflow
- Reproducibility: Terraform state, tfvars, versions, and Makefile commands

### 8) Reproduction Steps (quickstart)
1. cd CA1/terraform && cp terraform.tfvars.example terraform.tfvars && edit values
2. make deploy && make outputs
3. cd .. && make addrs && make verify
4. Optional: make verify-workflow MAX_DOCS=100
5. Teardown: cd terraform && make down

Teardown evidence:

```bash
cd CA1/terraform
make down
```

![tf destroy](CA1/screenshots/tf-destroy-07.png)

![verify destroy](CA1/screenshots/verify-destroy-12.png)


## CA2 — Orchestrated (Terraform + K3s on AWS)

Goal: Run the GPU analytics pipeline on a lightweight Kubernetes cluster (K3s) provisioned with Terraform, then deploy Kafka, MongoDB, Processor, and Producers as Kubernetes resources with Makefile automation.

Authoritative references for CA2:
- CA2 overview and workflow: CA2/README.md
- Architecture and decisions: CA2/architecture.md
- Conversation and evolution: CA2/conversation-summary.md

### 1) Software Stack and Layout (Kubernetes)
- Control plane + N worker nodes (EC2) with K3s installed
- Namespaces: platform (Kafka, MongoDB), app (Processor, Producers)
- Services:
  - Kafka (StatefulSet, headless Service)
  - MongoDB (StatefulSet, ClusterIP Service)
  - Processor (Deployment)
  - Producers (Deployment + optional HPA)

### 2) Environment Provisioning (Terraform)
Prereqs (local): Terraform ≥ 1.6, AWS CLI v2 configured, existing EC2 key pair, jq, curl.

Recommended flow using the CA2 Terraform Makefile (auto-detects your public IP for my_ip_cidr):

```bash
cd CA2/terraform
make deploy        # init + plan (with my_ip_cidr) + apply
make outputs       # show VPC/SG/instance outputs (cp IP, worker priv IPs)
```

Notes:
- Override AWS profile/region as needed: `AWS_PROFILE=terraform AWS_REGION=us-east-1 make deploy`
- Provide an explicit EC2 keypair name if not set in tfvars: `SSH_KEY_NAME=my-key make deploy`
- Security groups are created to allow:
  - 22/tcp from my_ip_cidr (admin)
  - 6443/tcp for kube-apiserver from my_ip_cidr
  - NodePorts (30000–32767) within the VPC (tunable in security_groups module)

### 3) Kubeconfig and Cluster Access

Before using kubectl, you must have a local CA2/.kube directory with a kubeconfig.yaml inside it. If it doesn't exist yet, create it:

```bash
cd CA2
mkdir -p .kube
# This file is written by 'make kubeconfig' or 'make bootstrap-k3s'
# touch .kube/kubeconfig.yaml    # optional placeholder
```
K3s is installed on the control plane via cloud-init. Copy the kubeconfig locally with the CA2 root Makefile:

```bash
cd CA2
make bootstrap-k3s    # scp /etc/rancher/k3s/k3s.yaml from control-plane → .kube/kubeconfig.yaml
make status        # KUBECONFIG=.kube/kubeconfig.yaml kubectl get nodes/pods
```

Tip: If your kubeconfig references 127.0.0.1, run a temporary tunnel while using kubectl:

```bash
make tunnel        # forwards localhost:6443 → control-plane:6443
```

### 4) Deploy Kubernetes Manifests
Apply all resources under CA2/k8s/ (namespaces, platform, app):

```bash
cd CA2
make deploy        # creates namespaces (idempotent), applies all manifests recursively
make status       # KUBECONFIG=.kube/kubeconfig.yaml kubectl get nodes/pods
```

### 5) Data Pipeline Verification
Use the CA2 Makefile helpers that read Terraform outputs to find node/VM addresses and verify services.

Common targets:

```bash
make addrs         # print private/public IPs from terraform outputs
make env           # print KAFKA_BOOTSTRAP / MONGO_URL / PROCESSOR_HEALTH (private IPs)

make verify        # runs verify-kafka, verify-mongo, verify-processor, verify-producers
make verify-workflow MAX_DOCS=100 WAIT_SEC=5  # end-to-end baseline→nudge→delta checks

# Spot checks
make verify-kafka
make verify-mongo
make verify-processor
make verify-producers
```

Optional: HPA scale test for producers (requires metrics-server):

```bash
make verify-scale-hpa HPA_NAME=producers BURST_RATE=500 HPA_TIMEOUT_SEC=300
```

### 6) Security Notes
- SSH: key-only; control plane exposes 22/tcp to my_ip_cidr
- Kubernetes API: 6443/tcp to my_ip_cidr
- Intra-cluster: kubelet and NodePorts allowed within VPC CIDR only
- App endpoints are cluster-internal (ClusterIP/Headless) and not Internet-exposed

### 7) Deliverables Checklist (what to include in CA2)
- Terraform evidence: plan/apply logs or screenshots; `make outputs`
- Terraform outputs: control_plane_public_ip, worker_private_ips, VPC/Subnet IDs
- Kubeconfig acquisition and `make status` showing nodes Ready
- Deployed resources: screenshots of `kubectl get pods -A` and verify targets
- Architecture link: CA2/architecture.md (cluster + namespaces)
- Short demo: `make verify-workflow` showing producers → Kafka → processor → MongoDB deltas
- Any deviations from the reference stack and rationale

### 8) Grading Mapping
- Correctness & Completeness: cluster up, services running, E2E verified via Makefile
- Security Controls: scoped SGs (admin IP, VPC-only NodePorts), SSH keys only
- Documentation & Diagrams: this README section + CA2/architecture.md + CA2/README.md
- Demo Quality: concise capture of verify/verify-workflow and status outputs
- Reproducibility: Terraform state, tfvars, and Makefile commands

### 9) Quickstart (TL;DR)
```bash
# 1) Provision infra
cd CA2/terraform
make deploy && make outputs

# 2) Pull kubeconfig and inspect cluster
cd ..
make kubeconfig
make status

# 3) Deploy everything
make deploy

# 4) Verify
make verify
make verify-workflow MAX_DOCS=100
```

### 10) Teardown
```bash
cd CA2/terraform
make down
```


### CA2 — Screenshots (by command order)

- Terraform deploy (part 1)
  
  ![make tf deploy 1](CA2/screenshots/make_tf_deploy_1.png)

- Terraform deploy (part 2)
  
  ![make tf deploy 2](CA2/screenshots/make_tf_deploy_2.png)

- Open tunnel to API server
  
  ![make tunnel](CA2/screenshots/make_tunnel_3.png)

- Bootstrap K3s and export kubeconfig
  
  ![make bootstrap-k3s](CA2/screenshots/make_bootstrap-k3s_4.png)

- Cluster status (nodes/pods)
  
  ![make status 1](CA2/screenshots/make_status_5.png)

- Apply Kubernetes manifests
  
  ![make deploy (k8s)](CA2/screenshots/make_kube_deploy_6.png)

- Cluster status after deploy
  
  ![make status 2](CA2/screenshots/make_status_7.png)

- Verify Kafka
  
  ![make verify-kafka](CA2/screenshots/make_verify-kafka_8.png)

- Verify MongoDB
  
  ![make verify-mongo](CA2/screenshots/make_verify-mongo_9.png)

- Verify Producers
  
  ![make verify-producers](CA2/screenshots/make_verify-producers_10.png)

- Verify Processor
  
  ![make verify-processor](CA2/screenshots/make_verify-processor_11.png)

- Verify end-to-end workflow
  
  ![make verify-workflow](CA2/screenshots/make_verify-workflow_12.png)

- Verify HPA scale (optional)
  
  ![make verify-scale-hpa](CA2/screenshots/make_verify-scale-hpa_13.png)

- Undeploy Kubernetes manifests
  
  ![make undeploy (k8s)](CA2/screenshots/make_kube_undeploy_14.png)

- Terraform destroy
  
  ![make down](CA2/screenshots/make_tf_down_15.png)


## CA3 — Cloud-Native Ops (Observability + Autoscaling + Logs)

Goal: Extend CA2 by adding a full observability stack (Prometheus, Grafana), centralized logs (Loki + Promtail), and autoscaling (HPA) to the GPU analytics pipeline on K3s.

Authoritative references for CA3:
- CA3 overview and workflow: CA3/README.md
- Architecture and decisions: CA3/docs/architecture.md
- SLIs and SLOs: CA3/docs/SLI.md, CA3/docs/SLO.md
- Conversation and evolution: CA3/docs/conversation-summary.md

### 1) Software Stack and Layout (Kubernetes + Monitoring)
- Namespaces:
  - platform: Kafka, MongoDB
  - app: Processor (FastAPI with `starlette_exporter`), Producers
  - monitoring: kube-prometheus-stack (Prometheus Operator, Prometheus, Alertmanager, Grafana), Loki, Promtail
- Services/Components:
  - Processor exposes `/metrics` for Prometheus scraping
  - HPA scales Producers based on CPU utilization
  - Grafana dashboards visualize pipeline throughput and system health

### 2) Environment Provisioning (Terraform)
Prereqs (local): Terraform ≥ 1.6, AWS CLI v2, existing EC2 key pair, jq, curl.

```bash
cd CA3/terraform
make deploy        # terraform init + plan + apply
make outputs       # show VPC/SG/instance outputs
```

Notes:
- Override AWS profile/region as needed: `AWS_PROFILE=terraform AWS_REGION=us-east-1 make deploy`
- Provide an explicit EC2 keypair name if not set in tfvars: `SSH_KEY_NAME=my-key make deploy`

### 3) Kubeconfig and Cluster Access
K3s is installed on the control plane and the kubeconfig is retrieved via the Makefile.

```bash
cd CA3
make bootstrap-k3s    # scp kubeconfig into CA3/.kube/kubeconfig.yaml
make status           # KUBECONFIG=.kube/kubeconfig.yaml kubectl get nodes/pods
```

### 4) Install Observability Stack
Installs Helm/metrics-server prerequisites and the kube-prometheus-stack with Loki/Promtail.

```bash
make bootstrap-monitoring-prereqs
make deploy-monitoring
```

Port-forward to access UIs:

```bash
# Grafana (http://localhost:3000) — login: admin / admin
KUBECONFIG=.kube/kubeconfig.yaml kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80

# Prometheus (http://localhost:9090)
KUBECONFIG=.kube/kubeconfig.yaml kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
```

### 5) Deploy Kubernetes Manifests (Platform + App)
```bash
make deploy        # applies Kafka + Mongo + Processor + Producers + HPA
make status        # confirm all pods Running
```

### 6) Data Pipeline Verification
Use the CA3 Makefile helpers:

```bash
make verify            # runs verify-kafka, verify-mongo, verify-processor, verify-producers
make verify-workflow   # end-to-end baseline→nudge→delta checks

# Spot checks
make verify-kafka
make verify-mongo
make verify-processor
make verify-producers

# Autoscaling demo (requires metrics-server)
make verify-scale-hpa
```

Logs and troubleshooting:
```bash
make K ARGS="-n platform logs -l app=kafka --tail=100"
make K ARGS="-n app logs -l app=processor --tail=100"
make K ARGS="-n monitoring logs -l app.kubernetes.io/name=loki --tail=100"
```

### 7) Security Notes
- No public workloads exposed; cluster services are ClusterIP/Headless by default
- Security Groups restricted to admin IP and intra-VPC traffic
- For full credit, add NetworkPolicies and manage sensitive values via External Secrets

### 8) Deliverables Checklist (what to include in CA3)
- Terraform evidence: plan/apply logs or screenshots; `make outputs`
- Kubeconfig retrieval and `make status` showing nodes Ready
- Monitoring stack proof: port-forwards, Prometheus targets Up, Grafana dashboards populated
- Deployed resources: `kubectl get pods -A` screenshots and verify targets
- Architecture link: CA3/docs/architecture.md; SLIs/SLOs (docs/SLI.md, docs/SLO.md)
- Short demo: `make verify-workflow` and HPA scaling (`make verify-scale-hpa`)
- Any deviations from CA2 stack and rationale

### 9) Grading Mapping
- Observability & Logs: kube-prometheus-stack installed; Processor `/metrics` scraped; Loki/Promtail logs visible
- Autoscaling: HPA scales Producers up/down under load; cooldown observed
- Documentation & Diagrams: this README section + CA3/README.md + CA3/docs/architecture.md
- Execution & Correctness: end-to-end flow verified; Mongo counts increase

### 10) Quickstart (TL;DR)
```bash
# 1) Provision infra
cd CA3/terraform
make deploy && make outputs

# 2) Pull kubeconfig and verify cluster
cd ..
make bootstrap-k3s
make status

# 3) Install monitoring stack
make bootstrap-monitoring-prereqs
make deploy-monitoring

# 4) Deploy everything
make deploy

# 5) Verify and demo scaling
make verify
make verify-workflow
make verify-scale-hpa
```

### 11) Teardown
```bash
cd CA3/terraform
make down
```

### CA3 — Screenshots (by command order)

- Deploy observability stack
  
  ![deploy monitoring](CA3/screenshots/deploy-all-monitoring-stack.png)

- Cluster status with monitoring
  
  ![make status with monitoring](CA3/screenshots/make%20status%20with%20monitoring.png)

- Port-forward Prometheus
  
  ![tunnel prometheus](CA3/screenshots/tunnel%20prometheus.png)

- Port-forward Grafana
  
  ![tunnel grafana](CA3/screenshots/tunnel%20grafana.png)

- Prometheus query: `up`
  
  ![prometheus query up](CA3/screenshots/prometheus-query-up.png)

- Prometheus `up` query visualization
  
  ![prometheus query up visualization](CA3/screenshots/prometheus-query-up-visualization.png)

- Prometheus Alerts
  
  ![prometheus alerts](CA3/screenshots/prometheus-alerts.png)

- Grafana Loki shows log data
  
  ![grafana loki data](CA3/screenshots/grafana-loki-data.png)
