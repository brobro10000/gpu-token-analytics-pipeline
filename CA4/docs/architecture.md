# Architecture — CA4

**(Colab GPU Producer + Edge K3s + Kafka + Worker + AWS VPC DB + S3 + Bastion)**

## Executive Summary

| Choice                                         | Why We Chose It                                                          | Pros                                                              | Cons / Risks                                                 | Future Scale Path                                          |
| ---------------------------------------------- | ------------------------------------------------------------------------ | ----------------------------------------------------------------- | ------------------------------------------------------------ | ---------------------------------------------------------- |
| **Colab GPU/TPU as Producer**                  | Offload heavy metadata extraction to free/low-cost accelerators          | Simple developer UX; no GPU infra to manage; fast iterations      | Ephemeral runtime; unstable network; limited SLA             | Move GPU pipeline to EKS node group, ECS GPU, or SageMaker |
| **K3s on EC2 (Edge Node Group)**               | Continue CA2/CA3 lineage with lightweight, self-managed k8s              | Low control-plane overhead; predictable; strong educational value | Ops-heavy: upgrades, failure recovery, node lifecycle        | Migrate to EKS with managed control plane + autoscaler     |
| **Processor API → Kafka (Option B only)**      | Clean contract between cloud producer & edge; keeps lineage from CA2/CA3 | Replay, buffering, decoupled scaling, event-driven                | Kafka STS still requires ops tuning; single cluster boundary | Move Kafka to MSK; partition topics; multi-broker KRaft    |
| **Worker (Kafka Consumer) → Managed Mongo DB** | Shifts durability to AWS while keeping transformations at edge           | Reliable persistence; multi-AZ; integrates with analytics         | DocumentDB vs Mongo differences; VPC access only             | Real Mongo Atlas cluster; multi-region replication         |
| **Bastion Host + SSH Tunnels**                 | Clear security boundary; avoids exposing Kafka/K3s endpoints             | No public control plane; keeps blast radius small                 | Manual tunneling; single operational choke-point             | Replace with SSM Session Manager or WireGuard              |
| **S3 Archive (Optional)**                      | Cheap data lake for raw/enriched metadata                                | Enables future ML retraining; ETL integration                     | Must manage lifecycle policies and access controls           | Mature into Glue/Athena + LakeFormation                    |
| **Prometheus + Loki + Grafana**                | Same observability stack as CA3; easy reuse                              | Familiar dashboards/logs; introspection of pipeline               | Retention limits; storage growth; manual scaling             | Add Thanos + S3 backend; managed Grafana Cloud             |

---

## Goals & Assumptions

* Extend CA3 into a **realistic cross-cloud pipeline**:
  **Colab (GCP)** for GPU work → **AWS VPC (Edge K3s)** for event and transformation pipeline → **AWS DB/S3** for persistence.
* Maintain **CA2/CA3 streaming lineage** using **Kafka as the internal event bus**.
* Move **durability out of the cluster** into AWS-managed services.
* Keep architecture **simple, reproducible, cost-efficient** for a student environment.
* Avoid public exposure of internals; all admin and dev access **must go through Bastion**.

---

## Benefits

### 1️⃣ Clear Multi-Cloud Boundary: Colab → Processor API → Kafka

The Processor API becomes the **sole gateway** into the edge system:

* Colab extracts embeddings, stats, metadata using GPU/TPU.
* It **POSTs** to `/metadata`.
* Processor API **validates/normalizes** the request.
* Processor API **publishes** to Kafka (`gpu-metadata` topic).

This creates a **stable API contract** shielding the internal architecture from Colab’s ephemeral nature.

---

### 2️⃣ Strong Streaming Semantics for Transformations

Kafka provides:

* **Replay** for debugging
* **Backpressure** during spikes
* **Decoupled scaling** of Processor API and Worker
* **Event-driven edge transformations**

This maintains CA2/CA3’s “stream-first” design while upgrading the environment.

---

### 3️⃣ Durable, Managed Persistence in AWS

Migrating the database from a Mongo StatefulSet to a **managed Mongo-compatible DB** inside the VPC provides:

* Backups & snapshots
* Multi-AZ durability
* No Kubernetes data-plane complexity
* Easy access from analytics tools

Optional S3 archiving extends the system into a **data-lake-friendly model**.

---

### 4️⃣ Secure & Controlled Access Through Bastion

Nothing inside the VPC is public.

Bastion enables:

* SSH → K3s API (via tunneling)
* SSH → Kafka (port forwarding)
* SSH → Grafana/Prometheus (optional)

This reduces the attack surface while remaining simple to operate in CA4.

---

## Updated Tradeoffs & Risks

### Reliability / HA

| Risk                                      | Why It Exists              | Impact                              | Mitigation Path                        |
| ----------------------------------------- | -------------------------- | ----------------------------------- | -------------------------------------- |
| K3s control plane self-hosted on one node | Simplicity over durability | API server outage halts deployments | EKS managed control plane              |
| Single Kafka broker (initially)           | CA2/CA3 lineage reused     | Broker failure halts ingestion      | Multi-broker Kafka; eventually MSK     |
| Colab runtime unreliability               | Free GPU service           | Jobs may interrupt or fail          | Move GPU tasks into AWS or on-prem GPU |

---

### Operations & Day-2 Concerns

| Issue                              | Cause                      | Impact                      | Future Improvement              |
| ---------------------------------- | -------------------------- | --------------------------- | ------------------------------- |
| Bastion requires manual tunneling  | Human SSH workflow         | Hard for teams; error-prone | SSM Session Manager / WireGuard |
| Kafka STS noisy and resource heavy | Stateful workload          | Logs + CPU spikes           | Move to MSK + fine-tuned quotas |
| Secrets stored in K8s              | Default Kubernetes storage | Not encrypted by default    | AWS Secrets Manager + ESO       |

---

### Security

| Concern                          | Reason                 | Mitigation                            |                                                 |
| -------------------------------- | ---------------------- | ------------------------------------- | ----------------------------------------------- |
| No public ingress                | Security-first posture | Requires tunneling for all UI access  | Acceptable for CA4; later add SSO-protected ALB |
| Plaintext Kafka internal traffic | Simplicity and reuse   | Allows snooping inside VPC            | mTLS or service mesh                            |
| Colab accessing VPC endpoint     | External origin        | Require VPN, IP allowlist, token auth |                                                 |

---

## Scalability Considerations

### Application Scaling

* **Processor API**
  Scales horizontally to handle POST bursts.
  Good signals: CPU, RPS, HTTP queue times.

* **Kafka**
  Higher throughput = increase partitions and broker count.
  Worker scaling is directly tied to **consumer lag**.

* **Worker**
  Purely horizontal scaling; best signal is Kafka lag.

### Data Scaling

* Move DB to a cluster mode (Atlas or multi-replica DocumentDB).
* Expand S3 lifecycle rules for long-term storage.

### Observability Scaling

* Prometheus & Loki can saturate local disk.
  Offload to S3 + Thanos for historical query performance.

---

## Alternative Approaches (With Tradeoffs)

| Alternative                           | Strengths                       | Drawbacks                  | When Appropriate             |
| ------------------------------------- | ------------------------------- | -------------------------- | ---------------------------- |
| EKS + MSK + Atlas                     | Fully managed; production-grade | Complexity + cost          | CA5 or production version    |
| All-on-AWS GPU (SageMaker or EC2 GPU) | No cross-cloud complexity       | Higher cost for GPU        | Enterprise workloads         |
| No streaming (API → DB direct)        | Simpler                         | Loses replay, backpressure | If streaming is not required |

---

## Cost Outlook

| Item                        | Rate           | Notes                              |
| --------------------------- | -------------- | ---------------------------------- |
| EC2 edge nodes (K3s)        | Similar to CA3 | Slight increase for DB integration |
| Managed Mongo-compatible DB | Moderate       | Chosen for durability and ease     |
| Bastion instance            | Low            | Single t-class                     |
| Prom + Loki disk            | Moderate       | Consider offloading to S3          |

---

## Hardening Roadmap

1. **Replace K3s with EKS**

    * Managed control plane
    * Autoscaler + IAM roles
2. **Move Kafka to MSK**

    * Multi-broker durability
    * Zero-maintenance scaling
3. **Shift Secrets to AWS SSM / Secrets Manager**

    * via External Secrets Operator
4. **Public ingress with TLS + Auth**

    * ALB ingress + OpenID Connect
5. **GPU producers inside AWS**

    * EKS GPU nodegroup
    * SageMaker Processing jobs
