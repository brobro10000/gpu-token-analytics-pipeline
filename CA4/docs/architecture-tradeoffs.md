# **Architecture Tradeoffs — CA4**



**(Colab GPU Producer → Local Processor API → Kafka in K3s → Worker → AWS DocumentDB/S3)**

## **Executive Summary**

| Choice                                             | Why We Chose It                                     | Pros                                                 | Cons / Risks                                             | Future-Ready Path                                 |
| -------------------------------------------------- | --------------------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------- | ------------------------------------------------- |
| **Google Colab GPU Producer**                      | Free GPU compute + simple HTTP integration          | Zero-cost accelerators; fast prototyping             | Ephemeral runtimes; unstable for long jobs               | Move extraction to EC2 GPU, EKS GPU, or SageMaker |
| **Local Processor API (FastAPI on laptop)**        | Faster iteration + avoids exposing AWS API publicly | Extremely fast dev loop; isolates complexity         | Requires tunnels; ingestion stops when laptop is offline | Deploy Processor API inside AWS (Ingress/VPN)     |
| **ngrok Ingress (Colab → Processor)**              | Easiest way to securely expose local dev API        | TLS, global reachability, minimal config             | External dependency; rotating URLs unless paid           | Replace with AWS API Gateway or private Ingress   |
| **Kafka in K3s (AWS VPC)**                         | Keeps CA2/CA3 event-driven lineage                  | Durable queue; replayable; strong separation         | Self-managed; needs manual ops; single broker            | Move to MSK or multi-broker PV-backed KRaft       |
| **Worker in K3s (AWS VPC)**                        | Centralized, production-like transformation tier    | Independent scaling; fault-tolerant; easy to monitor | Requires DB connectivity + namespace routing             | Add more workers; partition the topic             |
| **Managed Mongo-compatible DB (DocumentDB/Atlas)** | Provide a real persistent backend                   | Durable, backed up, multi-AZ                         | DocumentDB lacks full Mongo features                     | Use Atlas or multi-region clusters                |
| **Optional S3 archival**                           | Cheap long-term storage                             | Perfect for future ML, analytics                     | Requires lifecycle policies                              | Add Glue/Athena integration                       |
| **Bastion for all admin access**                   | Maintain a private VPC with no public K8s/Kafka     | Very secure; simple mental model                     | SSH tunnel fatigue; not team-scalable                    | Replace with SSM Session Manager or VPN           |
| **Prometheus + Loki + Grafana**                    | Same tooling as CA3, extended into AWS              | Good visibility into worker, Kafka, cluster          | Retention + volume concerns                              | Add Thanos + S3 backend; Managed Grafana          |

---

# **1. Goals & Architectural Intent**

CA4 intentionally demonstrates a **multi-cloud, event-driven pipeline**:

**GCP (Colab GPU compute)**
→ **Local ingestion / validation (Processor API)**
→ **AWS Kafka (stream backbone)**
→ **AWS Worker (transformations)**
→ **AWS DocumentDB / S3 (durable storage)**

Major goals:

* Replace CA3’s in-cluster ingestion pipeline with cross-cloud ingestion.
* Shift durability responsibility into AWS.
* Preserve the CA2/CA3 lineage of streaming + Kubernetes as the backbone.
* Keep cost reasonable (no MSK/EKS).
* Keep security model simple: VPC-private infra + bastion-only access.

---

# **2. Benefits of the Final Architecture**

## **1️⃣ Clear multi-cloud separation of concerns**

Colab handles *GPU-heavy extraction*.
Local Processor API handles *validation + event publishing*.
AWS handles *long-term storage, transformation, resilience*.

This mirrors real enterprise pipelines where compute often occurs at the “edge” (remote device, on-prem GPU box) and data flows into a cloud backbone.

---

## **2️⃣ Strong event-driven processing model (Kafka → Worker)**

Kafka enables:

* Replay
* Ordered partitioning
* Backpressure handling
* Separation of ingestion and processing

The Worker consumes from `gpu-metadata`, making transformations independent of:

* Colab runtime restarts
* Processor API vs Edge API location

This creates a **resilient, asynchronous ingestion story**.

---

## **3️⃣ Durable storage with AWS-managed services**

DocumentDB (or Mongo Atlas):

* Holds `ca4.gpu_metadata` collection.
* Survives pod/node failures.
* Supports indexing, analytics, dashboards.

S3 archives open the door to:

* Long-term retention
* ML retraining
* Glue/Athena
* Data lake patterns

---

## **4️⃣ Realistic cloud security posture**

* **No public Kafka**
* **No public Mongo**
* **No public Kubernetes API**
* **Only the bastion is reachable**

This is a **production-style private topology**, not a toy deployment.

---

## **5️⃣ Observability parity with CA3 but improved for AWS**

Prometheus → metrics
Loki → logs
Grafana → dashboards

You now have visibility into:

* Worker pipeline throughput
* Kafka broker health
* Mongo connection success
* K3s cluster operations

---

# **3. Tradeoffs & Constraints**

## **A. Reliability Risks**

| Risk                               | Impact                              | Why                                                   | Mitigation                                     |
| ---------------------------------- | ----------------------------------- | ----------------------------------------------------- | ---------------------------------------------- |
| **Local Processor API dependency** | Ingestion stops if laptop turns off | You're terminating the public API on your workstation | Deploy Processor API in-cluster behind Ingress |
| **Single Kafka broker**            | Message loss or downtime            | K3s cluster is small; only 1 broker                   | Move to multi-broker Kafka; adopt MSK          |
| **Bastion as a single chokepoint** | Loss of admin access                | Bastion failure blocks all tunnels                    | Add SSM Session Manager or backup bastion      |

---

## **B. Operations & Developer Experience**

| Issue              | Cause                    | Effect                   | Future Fix                          |
| ------------------ | ------------------------ | ------------------------ | ----------------------------------- |
| Manual SSH tunnels | Bastion-based access     | Hard to teach, can break | Replace with WireGuard or SSM       |
| Colab instability  | Ephemeral runtime        | Breaks long tests        | Move producer into AWS or local GPU |
| Self-managed Kafka | Stateful workload in K3s | Operational complexity   | Use Amazon MSK                      |

---

## **C. Security**

| Concern          | Reason                      | Mitigation                          |                                             |
| ---------------- | --------------------------- | ----------------------------------- | ------------------------------------------- |
| ngrok exposure   | Local Processor made public | Use auth tokens + HTTPS; rotate URL | Replace with API Gateway or private Ingress |
| Bastion reliance | SSH keys, human access      | Use MFA + short-lived certs         | Adopt IAM-backed SSM                        |

---

# **4. Scalability Potential**

## **Application Tier**

* Processor API → scales horizontally when migrated into AWS.
* Worker → replicate N times; scale on Kafka lag.

## **Streaming Tier**

* Partition Kafka topic into N shards.
* Add brokers for throughput & resilience.

## **Storage Tier**

* DocumentDB/Atlas → add replicas or vertical scale.
* S3 → essentially infinite.

## **Monitoring Tier**

* Add Thanos to export Prometheus metrics to S3.
* Use Managed Grafana.

---

# **5. Alternative Architecture Patterns**

| Alternative                               | Strengths                  | Drawbacks                   | When To Use                             |
| ----------------------------------------- | -------------------------- | --------------------------- | --------------------------------------- |
| **Fully managed AWS (EKS + MSK + Atlas)** | Enterprise-grade, reliable | Higher cost + complexity    | True production deployment              |
| **Single-cloud AWS-only**                 | Simplifies networking      | Loses multi-cloud narrative | When constrained by networking policies |
| **Direct API → DB (no Kafka)**            | Simplest                   | No replay, no backpressure  | Tiny workloads or early prototypes      |

---

# **6. Hardening Roadmap (Post-CA4)**

1. Deploy Processor API inside the cluster behind Ingress.
2. Enable Kafka TLS + mTLS.
3. Move Kafka to MSK or KRaft multi-broker.
4. Add SSM Session Manager for bastionless access.
5. Introduce API versioning and authentication.
6. Replace Colab with durable GPU compute.

---

# **Conclusion**

The final CA4 design demonstrates:

* Multi-cloud ingestion
* Event-driven processing
* Edge Kubernetes operations
* Durable AWS persistence
* Secure private networking
* Observability across the entire stack

It preserves the **CA2/CA3 lineage** while delivering a **realistic modern cloud architecture** appropriate for a capstone project.
