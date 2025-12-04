# **CA4 Agent Implementation Guide**

*This document provides a complete, deterministic specification for an autonomous agent to build CA4 using the existing CA2/CA3 repository foundation.*

---

# **1. Mission**

Implement **CA4: Cross-Cloud GPU Metadata Processing Pipeline**, using:

* **Colab (GCP)** as GPU/TPU metadata producer
* **AWS VPC** as the core streaming and persistence environment
* **K3s on EC2** for Processor API, Kafka event bus, Worker, and Observability
* **Managed Mongo-compatible DB** for durable storage
* **S3** for optional raw/enriched metadata archives
* **Bastion host + SSH tunneling** for secure interaction
* **Makefiles + Terraform + kubectl** orchestrating the entire lifecycle

The system preserves CA2/CA3 lineage (Kafka-backed transformations) while extending into a multi-cloud architecture.

---

# **2. Inputs the Agent Must Use**

The agent **must read and follow**:

### **2.1 CA4 Architecture Diagram**

File: `architecture-ca4.puml`
Defines:

* Components
* Namespaces
* Deployment topology
* Data flow (Colab → API → Kafka → Worker → DB/S3)

### **2.2 CA4 Provisioning Sequence Diagram**

File: `ca4-provisioning-sequence.puml`
Defines:

* Terraform + Make invocation order
* Bootstrapping K3s
* Secret/config provisioning
* Deployment ordering
* E2E validation pipeline

### **2.3 CA4 Makefile Contract**

File: `ca4/MAKEFILE-CONTRACT.md`
Defines:

* Terraform make targets
* Root Makefile targets
* Expected inputs, outputs, and side-effects
* Required target naming conventions

### **2.4 CA2/CA3 Repository Structure**

Agent must reuse:

* CA3 Terraform module layout
* CA3 folder conventions
* CA3 monitoring stack manifests
* CA3 Makefile patterns
* CA3 Kubernetes manifests as starting templates

### **2.5 Additional Provided Files**

* `architecture.puml`
* `provisioning-sequence-final.puml`
* `Makefile` (root-level)
* `ca3/terraform/Makefile`

---

# **3. Outputs the Agent Must Produce**

The agent must generate the **fully structured CA4 implementation**, consisting of:

### **3.1 Directory Structure**

```
ca4/
  terraform/
    main.tf
    variables.tf
    outputs.tf
    Makefile
    modules/ (if needed)
  k8s/
    platform/
      kafka.yaml
      namespaces.yaml
      secrets.yaml
    app/
      processor-api.yaml
      metadata-worker.yaml
    monitoring/
      prom.yaml
      loki.yaml
      grafana.yaml
  scripts/
    bootstrap_k3s_ca4.sh
  AGENT_IMPLEMENTATION.md  ← this file
  README.md                ← optional human summary
```

### **3.2 Working Infrastructure**

Provisioned via:

```
make ca4-plan
make ca4-apply
```

Creates:

* VPC
* Subnets
* SGs
* Bastion
* Edge node group
* Managed Mongo-compatible DB
* S3 bucket

### **3.3 Operational K3s Cluster**

Bootstrapped via:

```
make ca4-bootstrap-k3s
```

### **3.4 Fully Deployed Platform**

Installed via:

```
make ca4-platform-setup
make ca4-deploy-edge
make ca4-deploy-monitoring
```

### **3.5 E2E Operational Pipeline**

Validated via:

```
make ca4-verify-e2e
```

---

# **4. Implementation Steps Required**

Below is the **step-by-step workflow** the agent must follow.

---

## **Step 1 — Scaffold CA4 Terraform (ca4/terraform/)**

The agent must:

1. Copy CA3 Terraform module structure.

2. Update variables for CA4:

    * `my_ip_cidr`
    * `ssh_key_name`
    * `edge_node_instance_type`
    * `db_username`, `db_password`, `db_cluster_params`

3. Create new resources:

    * AWS VPC (reuse CA3 but with CA4 naming)
    * Private + public subnets
    * Security groups for:

        * Bastion
        * K3s nodes
        * DB access
    * Bastion host EC2 instance
    * Edge EC2 node group for K3s
    * DocumentDB / Atlas cluster
    * S3 bucket for CA4 archives

4. Ensure outputs include:

    * Bastion public IP
    * Edge node private IPs
    * DocumentDB endpoint
    * S3 bucket URL
    * K3s API internal endpoint (optional)

5. Implement Terraform Makefile (see contract):

    * `plan`, `apply`, `destroy`, `show`, `state`, `clean`, `nuke`.

---

## **Step 2 — Implement Root-Level Make Targets**

The agent must add targets matching contract:

### Required:

* `ca4-plan`
* `ca4-apply`
* `ca4-destroy`
* `ca4-bootstrap-k3s`
* `ca4-platform-setup`
* `ca4-deploy-edge`
* `ca4-deploy-monitoring`
* `ca4-verify-preflight`
* `ca4-verify-kafka`
* `ca4-verify-db`
* `ca4-verify-e2e`

These must delegate to:

```
ca4/terraform/Makefile
scripts/bootstrap_k3s_ca4.sh
kubectl apply -f ca4/k8s/<...>
```

---

## **Step 3 — Bootstrap K3s on Edge Nodes**

The agent must create:

```
scripts/bootstrap_k3s_ca4.sh
```

The script must:

* SSH into edge EC2 nodes via bastion hop:

  ```
  ssh -J bastion user@edge-node
  ```
* Install K3s server/agent.
* Write kubeconfig to a known location:

  ```
  ./kubeconfigs/ca4-kubeconfig
  ```
* Patch server IP and ensure port `6443` connectivity.

---

## **Step 4 — Create CA4 Kubernetes Manifests**

### 4.1 Namespaces

`platform`, `app`, `monitoring`

### 4.2 Secrets

Agent must generate manifests using Terraform outputs:

* `ca4-mongo-credentials`
* `ca4-s3-config`
* `ca4-edge-api-config`

### 4.3 Processor API (Edge)

Deployment + Service containing:

* Container image (use CA3 processor as base)
* `/metadata` POST endpoint
* Publishes to Kafka topic `gpu-metadata`
* Reads DB info from Secret

### 4.4 Kafka

* StatefulSet for 1–3 brokers
* Headless service
* Topic provisioning job (optional)
* Must support edge-worker consumption

### 4.5 Metadata Worker

* Deployment consuming from Kafka
* Writes to Mongo-compatible DB
* Applies transformation rules
* Optional S3 write

### 4.6 Monitoring Stack

Reuse CA3 manifests with CA4 namespace changes:

* Prometheus
* Loki + Promtail
* Grafana + dashboards

---

## **Step 5 — Wire Terraform Outputs into Kubernetes**

The agent must build a target:

```
make ca4-platform-setup
```

Which:

* Fetches Terraform outputs via:

  ```
  terraform -chdir=ca4/terraform output -raw <name>
  ```
* Writes them to:

    * Secrets (`MONGO_URI`)
    * ConfigMaps (e.g. `EDGE_API_URL`)
* Applies base manifests.

---

## **Step 6 — Deploy Edge Workloads**

The agent must:

```
make ca4-deploy-edge
```

Which applies deployments:

* `processor-api.yaml`
* `kafka.yaml`
* `metadata-worker.yaml`

All must reach `Ready` state.

---

## **Step 7 — Deploy Monitoring Stack**

Run:

```
make ca4-deploy-monitoring
```

Agent must ensure:

* Prometheus scraping rules added for:

    * Processor API
    * Kafka brokers
    * Worker
    * DB exporter (if added)

* Loki receiving logs from Promtail.

---

## **Step 8 — Configure SSH Tunnels**

Agent must generate documentation or script enabling:

### Local → Bastion → VPC tunnels:

* Kafka:
  `ssh -L 19092:<internal-kafka>:9092`
* Grafana:
  `ssh -L 3000:<grafana-svc>:3000`
* K3s API:
  `ssh -L 16443:<k3s-api>:6443`

These tunnels must allow:

* Kafka CLI access
* K3s kubectl access
* Grafana dashboard access

---

## **Step 9 — Colab Integration**

Agent must provide a minimal Colab client example:

```python
import requests, json, os

EDGE_API_URL = os.getenv("EDGE_API_URL")
payload = {...}   # Metadata extracted by GPU

resp = requests.post(f"{EDGE_API_URL}/metadata", json=payload)
resp.raise_for_status()
```

Colab must **not** connect directly to Kafka or DB.

---

## **Step 10 — Verification Procedures**

Agent must implement:

### 10.1 Preflight

Validate all nodes/pods required for CA4.

### 10.2 Kafka check

Confirm topic `gpu-metadata` exists.

### 10.3 DB check

Perform insert/read via Worker or toolbox pod.

### 10.4 End-to-end test

```
Colab → Processor API → Kafka → Worker → DB (+ S3 optional)
```

Test must confirm:

* Published message consumed
* Worker log events visible
* DB document count increases
* Grafana dashboard updates

---

# **11. Done Criteria**

The CA4 implementation is **complete** when:

* `make ca4-plan` produces valid TF plan
* `make ca4-apply` provisions CA4 infra
* `make ca4-bootstrap-k3s` yields working K3s cluster
* `make ca4-deploy-edge` installs Processor API, Kafka, Worker
* `make ca4-verify-e2e` shows successful end-to-end flow
* Grafana dashboards display CA4 activity
* Colab notebook can successfully post metadata

---

# **12. Agent Notes (Rules of Engagement)**

* **Preserve CA2/CA3 folder structure.**
* **Never modify CA3 resources.** CA4 must be isolated.
* **All CA4 Makefile targets must match the contract.**
* **All connections inside VPC must be private.**
* **Processor API must not write directly to DB (Option B only).**
* **All access must pass through bastion unless in-cluster.**
* **Colab only communicates via Processor API, never Kafka or DB.**
* **Code generation must be deterministic and idempotent.**
