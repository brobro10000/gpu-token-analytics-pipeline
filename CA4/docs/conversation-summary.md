# **CA4 Conversation Summary**

### **Objective**

Extend CA3 into a **multi-cloud, GPU-accelerated metadata processing pipeline** where:

* **Colab (GCP)** performs GPU/TPU-based metadata extraction
* **AWS VPC** hosts the core streaming and transformation pipeline
* **Edge K3s cluster** processes incoming metadata via:

    * Processor API (ingress point)
    * Kafka (internal event bus)
    * Worker (consumer → transform → persist)
* **Managed Mongo-compatible DB** serves as durable system-of-record
* **S3** acts as optional archive storage
* **Bastion host + SSH tunneling** provides secure operational access
* **Prometheus, Loki, Grafana** provide observability of the entire pipeline

The system must retain CA2/CA3 lineage—especially Kafka streaming semantics—while introducing **cross-cloud data flow**, **secure access boundaries**, and **managed persistence** appropriate for CA4.

---

### **Core Components (as designed)**

| Component                       | Location                   | Type                    | Notes                                                                                   |
| ------------------------------- | -------------------------- | ----------------------- | --------------------------------------------------------------------------------------- |
| **Colab GPU Notebook Producer** | GCP                        | Python Notebook         | Performs raw data ingestion, GPU/TPU-based metadata extraction, sends POST `/metadata`. |
| **Processor API (Local Dev)**   | Developer Laptop           | Docker container        | Mirrors Edge API; publishes to Kafka via SSH tunnel.                                    |
| **Bastion Host**                | AWS VPC                    | EC2                     | SSH jump point; tunnels to Kafka, K3s API, Grafana.                                     |
| **Edge K3s Cluster**            | AWS EC2 Node Group         | K3s                     | Hosts Processor API, Kafka, Worker, Promtail, Monitoring Stack.                         |
| **Processor API (Edge)**        | K3s `app` namespace        | Deployment + Service    | Ingress for Colab; validates, normalizes, publishes to Kafka.                           |
| **Kafka**                       | K3s `platform` namespace   | StatefulSet             | Internal bus; topic `gpu-metadata`.                                                     |
| **Metadata Worker**             | K3s `app` namespace        | Deployment              | Kafka consumer; transforms metadata; writes to DB + optional S3.                        |
| **Managed Mongo-compatible DB** | AWS VPC                    | DocumentDB/Atlas        | Durable, multi-AZ persistence layer.                                                    |
| **S3 Bucket**                   | AWS VPC                    | Storage                 | Optional raw/enriched metadata archives.                                                |
| **Prometheus**                  | K3s `monitoring` namespace | Deployment              | Scrapes Processor, Kafka, Worker, DB metrics.                                           |
| **Loki + Promtail**             | K3s `monitoring` namespace | DaemonSet + StatefulSet | Centralized log aggregator for CA4 services.                                            |
| **Grafana**                     | K3s `monitoring` namespace | Deployment              | CA4 dashboards for API throughput, Kafka lag, Worker transforms, DB writes.             |

---

### **Processing Pipeline (Data Flow)**

```
Raw Data (images, logs, metrics)
           ↓ (GPU/TPU extraction)
Colab Producer (GCP)
           ↓ POST /metadata
Processor API (Edge, AWS VPC)
           ↓ publish
Kafka Topic: gpu-metadata
           ↓ consume (consumer group: edge-worker)
Metadata Worker
           ↓ transform
Managed Mongo-compatible DB
           ↓ optional archive
AWS S3 Bucket
```

**Observability path:**

```
Processor / Worker / Kafka / DB Metrics → Prometheus
Logs (all pods) → Promtail → Loki
Prometheus + Loki → Grafana Dashboards
```

---

### **Provisioning Workflow (As Derived From CA4 PUML)**

| Stage                           | Commands/Actions                   | Description                                                                       |
| ------------------------------- | ---------------------------------- | --------------------------------------------------------------------------------- |
| **1. Provision AWS Infra**      | `make ca4-plan` / `make ca4-apply` | Creates VPC, subnets, SGs, bastion, edge node group, DocumentDB/Atlas, S3 bucket. |
| **2. Bootstrap K3s**            | `make ca4-bootstrap-k3s`           | Install K3s on EC2 edge nodes; retrieve `kubeconfig-ca4.yaml`.                    |
| **3. Platform Setup**           | `make ca4-platform-setup`          | Create namespaces (`platform`, `app`, `monitoring`), Secrets, ConfigMaps.         |
| **4. Deploy Edge Workloads**    | `make ca4-deploy-edge`             | Deploy Processor API, Kafka STS, Metadata Worker.                                 |
| **5. Deploy Monitoring Stack**  | `make ca4-deploy-monitoring`       | Install Prometheus, Loki, Grafana, Promtail.                                      |
| **6. Configure SSH Tunnels**    | Manual (`ssh -L ...`)              | Tunnel local ports → K3s API, Kafka broker(s), Grafana.                           |
| **7. Configure Colab Notebook** | Set `EDGE_API_URL`                 | Point notebook at Processor API ingress endpoint.                                 |
| **8. Preflight Verification**   | `make ca4-verify-*`                | Validate nodes, pods, Kafka topic, DB connectivity.                               |
| **9. E2E System Test**          | Execute Colab test cell            | Validate Colab → API → Kafka → Worker → DB (+ S3).                                |
| **10. Observability Check**     | Grafana Dashboard Load             | Confirm metrics/log flows.                                                        |

---

### **Key Implementation Points**

* **Option B only** is used: Processor API **never** writes directly to DB—only publishes to Kafka.
* Kafka topic **`gpu-metadata`** is the central event stream for CA4.
* Worker enforces **idempotent** writes into the Mongo-compatible DB.
* All AWS resources (DB, S3, EC2 nodes) remain inside the **VPC** with private subnets.
* Bastion host is the **only admin access path**, using SSH tunneling for:

    * K3s API
    * Kafka broker(s)
    * Grafana / Prometheus UIs
* Processor API schema: `POST /metadata` JSON payload (GPU/TPU-extracted metadata).
* Colab communicates over **HTTPS Ingress or VPN** to Processor API.
* Monitoring stack reused from CA3 with CA4-specific dashboards added.
* DB connection strings and AWS endpoints supplied to Worker via Secrets produced by Terraform outputs.

---

### **Current System Architecture (Final)**

**Multi-cloud GPU → Edge Streaming → Managed Persistence Pipeline**

* **Colab (GCP)** performs compute-heavy extraction.
* **AWS VPC** hosts the streaming/transformation pipeline.
* **K3s** provides lightweight orchestration for Processor API, Kafka, Worker, and monitoring.
* **AWS-managed DB** ensures durable, reliable storage.
* **S3** provides archive-level persistence.
* **Bastion** secures access without exposing control-plane or brokers publicly.

The resulting architecture is production-adjacent while still maintaining the educational, hands-on nature of CA2/CA3.

---

### **Next Recommended Enhancements**

1. Replace Bastion SSH access with **AWS SSM Session Manager**.
2. Promote K3s to **EKS** with cluster autoscaler + managed control plane.
3. Move Kafka from in-cluster STS to **Amazon MSK**.
4. Implement end-to-end **TLS/mTLS** for API + Kafka traffic.
5. Introduce **multi-broker Kafka topology** with partition-based scaling.
6. Add **versioned API** for backward-compatible changes to Colab producer.
7. Offload metrics/log retention to **Thanos + S3**.
