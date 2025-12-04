# **CA4 Conversation Summary (Updated Through Final Architecture Decisions)**



## **Objective**

Extend CA3 into **CA4**, a multi-cloud, GPU-accelerated metadata ingestion and streaming pipeline that performs:

* **GPU/TPU metadata extraction in Google Colab**
* **Local or Edge-based metadata validation and ingestion via Processor API**
* **Event-based streaming via Kafka inside an AWS VPC**
* **Metadata transformation via Worker containers running on K3s**
* **Durable persistence to AWS DocumentDB / Mongo Atlas**
* **Optional archival to S3**
* **System-wide observability through Prometheus, Loki, and Grafana**

The architecture maintains full lineage with CA2/CA3 while introducing:

* Cross-cloud ingestion
* SSH bastion tunneling for private Kafka access
* ngrok-enabled local development
* Agentic workflows for execution and provisioning

---

# **Core Architecture Components**

| Component                       | Location           | Purpose                                                                                                       |
| ------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------- |
| **Colab GPU Notebook Producer** | Google Colab (GCP) | Extracts embeddings + GPU hardware metadata; POSTs JSON payloads to Processor API (via ngrok or AWS ingress). |
| **Processor API (Local Dev)**   | Developer Laptop   | Receives GPU metadata; publishes to Kafka through SSH bastion tunnel.                                         |
| **ngrok**                       | Internet           | Exposes local FastAPI instance with a public HTTPS endpoint for Colab.                                        |
| **Bastion Host**                | AWS VPC            | Secure SSH gateway; forwards Kafka / Grafana / K3s traffic.                                                   |
| **K3s Cluster (Edge Nodes)**    | AWS EC2            | Hosts Processor API (edge), Kafka, Worker, and monitoring stack.                                              |
| **Kafka (gpu-metadata topic)**  | K3s / AWS VPC      | Internal event bus for CA4 ingestion pipeline.                                                                |
| **Metadata Worker**             | K3s                | Consumes Kafka events, transforms metadata, and writes to DB/S3.                                              |
| **DocumentDB / Atlas**          | AWS VPC            | Durable storage of transformed metadata.                                                                      |
| **S3 Archive**                  | AWS                | Optional archival of raw or enriched artifacts.                                                               |
| **Prometheus + Loki + Grafana** | K3s                | Holistic observability: metrics + logs + dashboards.                                                          |

---

# **Pipeline Summary (Final CA4 Data Flow)**

```
Raw Data (images, logs)
        ↓ GPU/TPU Extraction
Colab Producer
        ↓ POST /metadata
ngrok (dev) or AWS Ingress (prod)
        ↓
Processor API (Local or Edge)
        ↓ publish
Kafka Topic: gpu-metadata
        ↓ consume
Metadata Worker (K3s)
        ↓ transform
DocumentDB (primary)
        ↓ optional
S3 Archive
```

### Observability:

```
Processor / Worker / Kafka / DB
       ↓ metrics
   Prometheus
       ↓ logs
   Loki ← Promtail
       ↓ dashboards
   Grafana
```

---

# **Key Updates & Clarifications Added in Recent Discussions**

### ✔ ngrok is used for **Colab → Local API ingestion**

Enables full pipeline testing without deploying edge API.

### ✔ SSH tunneling via bastion is required for **local → Kafka connectivity**

Because Kafka exists only inside a **private AWS VPC**, local development relies on:

```bash
ssh -L 9092:kafka-0.kafka-svc.platform.svc.cluster.local:9092 ec2-user@BASTION
```

This makes Kafka reachable at `localhost:9092` for the local Processor API.

### ✔ Production mode requires no tunnels

All traffic remains inside the VPC.

### ✔ GPU metadata is enriched with hardware details

Using PyTorch CUDA APIs:

* device name
* total memory
* allocated memory
* compute capability
* CUDA version
* PyTorch version

### ✔ CA4 prioritizes **Option B: event-driven ingestion**

Processor API never writes to DB directly; it **only publishes to Kafka**.

### ✔ Agentic workflow introduced

Agents can:

* Interpret PlantUML diagrams
* Execute Makefile targets
* Bring up infrastructure
* Validate ingestion
* Use observability tools to debug the system

This moves CA4 toward autonomous reproducibility.

---

# **Provisioning Summary**

### 1. **Terraform Layer**

* Provision VPC, Bastion, EC2 node pool, SGs, DocumentDB/S3.

### 2. **K3s Bootstrap**

* install K3s on EC2 nodes
* fetch kubeconfig
* configure TLS SANs

### 3. **Platform Deployment**

* Kafka
* Prometheus, Loki, Grafana
* Namespaces + RBAC

### 4. **App Deployment**

* Processor API (edge)
* Kafka Worker
* Secrets + environment configs

### 5. **Dev Mode Setup**

* Start local FastAPI
* Expose through ngrok
* Start SSH tunnel
* Run Colab extraction notebook

### 6. **E2E Verification**

* Colab sends GPU metadata via /metadata
* Processor publishes to Kafka
* Worker writes to DB
* Grafana + Loki confirm ingestion

---

# **Tradeoffs Finalized in CA4**

| Tradeoff                                      | Consequence                                                    |
| --------------------------------------------- | -------------------------------------------------------------- |
| **Multi-cloud complexity**                    | Requires careful connectivity between GCP → Laptop → AWS.      |
| **SSH tunnels in dev**                        | Extra step, but ensures VPC remains private.                   |
| **Kafka inside K3s**                          | Stateful; adds operational overhead but keeps CA2/CA3 lineage. |
| **Processor API cannot directly write to DB** | Enforces clean streaming architecture.                         |
| **ngrok not for production**                  | Only used for dev-mode ingestion.                              |

---

# **State of the System After Completion**

CA4 now provides:

* A **cloud-to-edge ingestion pipeline**
* Strong **security boundaries** via private VPC & bastion
* **Scalable streaming backbone** via Kafka
* **GPU-accelerated metadata extraction**
* **Full observability**
* A provisioning sequence and architecture that an **agent can fully implement**

This final architecture is stable, reproducible, and ready for demonstration or extension into CA5.