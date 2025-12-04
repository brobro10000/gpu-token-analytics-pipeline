# Architecture Tradeoffs — CA4

**(Colab GPU Producer + Edge K3s on EC2 + AWS VPC DB + Internal Kafka + Bastion)**

## Executive Summary

| Choice                                                   | Why We Chose It                                                                               | Pros                                                                                    | Cons / Risks                                                                     | Future Scale Path                                                                            |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **Google Colab GPU/TPU as Producer**                     | Reuse free/cheap GPU/TPU notebooks as the “cloud-side” producer for heavy metadata extraction | Easy access to accelerators; great pedagogical value; simple HTTP integration           | Ephemeral runtimes; network constraints; limited control over scheduling         | Move to dedicated GPU nodes (EKS / SageMaker / on-prem GPU) with same HTTP contract          |
| **Self-managed K3s on EC2 (Edge Node Group in AWS VPC)** | Preserve CA2/CA3 lineage while relocating the edge cluster into an AWS VPC                    | Reuses existing K3s knowledge; low control-plane overhead; full control of node layout  | Ongoing ops toil (patching, recovery, upgrades); no managed control plane        | Migrate to **EKS** node groups with managed control plane and cluster autoscaler             |
| **HTTP Processor API (Edge)**                            | Make cross-site integration simple and robust: Colab → HTTPS → Processor API → Kafka          | Clean contract; easy to test from anywhere; enables auth, rate limiting, and versioning | Adds another hop before Kafka; must handle retries and validation                | Add API Gateway / private ALB, mTLS, and versioned API; split read vs write paths            |
| **Internal Kafka (K8s StatefulSet) as Event Bus**        | Keep CA2/CA3 streaming semantics while hiding Kafka inside the VPC                            | Strong queueing/backpressure semantics; replay; familiar CA3 topology                   | Operationally heavy (ZK/KRaft, storage, monitoring); still single-cluster        | Move to **MSK** or a hardened multi-broker Kafka with proper PVs and KRaft                   |
| **Metadata Processor Worker (K8s Deployment)**           | Dedicated consumer/transformer stage for edge-enrichment and DB writes                        | Clear separation of concerns; independently scalable; fits HPA well                     | Requires careful schema evolution and idempotency; backpressure logic lives here | Add more workers, partition topics, or split into multiple specialized workers               |
| **Managed Mongo-compatible DB in AWS VPC**               | Shift “source of truth” from in-cluster Mongo to managed persistence inside AWS               | Durable, managed backups, multi-AZ; easy to connect other AWS services                  | Higher cost vs DIY; some Mongo features may differ (DocumentDB vs real Mongo)    | Use multi-region clusters; add analytics replicas; integrate with downstream warehouses      |
| **S3 for Raw/Enriched Archive (Optional)**               | Cheap, durable storage for raw inputs and enriched outputs                                    | Great for offline analysis, ML retraining, and compliance                               | Additional copy of data → governance and lifecycle management needed             | Add lifecycle rules, Glue/Athena on top, and forward into data lake patterns                 |
| **Bastion Host + SSH Tunnels for Admin & Dev**           | Simple, explainable model for secure cluster access and Kafka exposure                        | No public control-plane exposure; easy to reason about for CA4                          | Manual tunnel management; brittle if misconfigured; doesn’t scale to teams well  | Replace bastion with SSM Session Manager / WireGuard; adopt VPN-based or SSO-backed access   |
| **Prometheus + Loki + Grafana in/near K3s**              | Same observability stack as CA3, extended to AWS VPC                                          | Strong familiarity; unified metrics/logs; powerful dashboards                           | Resource overhead on small node groups; log/metrics retention limited            | Offload storage to S3/Thanos; host Grafana as a managed service; multi-cluster observability |

---

## Goals & Assumptions

* **Multi-site story:**
  Demonstrate a realistic pattern where **GPU/TPU work happens in one cloud (GCP/Colab)** and **stream processing + persistence happens in another (AWS VPC)**.

* **Preserve CA2/CA3 lineage:**
  Keep **Kafka + K3s + Worker** as the internal streaming backbone while changing where the cluster and DB live.

* **Shift durability into AWS:**
  Treat the **managed Mongo-compatible DB in VPC** as the **system of record**, not the Colab notebook or the edge pod filesystem.

* **Keep cost and complexity bounded:**
  No EKS/MSK yet; still **self-managed K3s + Kafka** to maintain continuity and hands-on operations.

* **Security via “small blast radius”:**

    * **No public Kafka / Mongo**
    * Access through **bastion + SSH tunneling** and/or private ingress

---

## Benefits

### 1️⃣ Clear Cloud-to-Edge Contract

* Colab producer only needs to know:
  `POST /metadata` to the Processor API (dev: `localhost:8000`; prod: edge URL in the VPC).
* All **complexity stays behind the API**:

    * Validation, normalization
    * Publishing to Kafka
    * Downstream transformations and DB writes

This keeps the **Producer side “dumb but powerful”**: throw compute at metadata extraction, then fire-and-forget to the API.

---

### 2️⃣ Strong Streaming & Processing Story (Kafka + Worker)

* Kafka remains an **internal event bus**:

    * No WAN exposure
    * CA2/CA3 mental model still applies
* The **Metadata Processor Worker**:

    * Consumes from `gpu-metadata` topic
    * Applies edge transforms / aggregations
    * Writes canonical documents into the VPC DB

This gives you **backpressure, replay, and multiple consumer potential** (future analysis jobs, anomaly detectors, etc.) without complicating the Colab side.

---

### 3️⃣ Durability and Integrations via AWS DB + S3

* The **managed DB** inside the VPC:

    * Survives node failures and reboots
    * Can be attached to **analytics, dashboards, ETL** without touching K3s internals
* Optional **S3 archive**:

    * Keeps raw and/or enriched data
    * Opens path to **Glue, Athena, EMR, LakeFormation**, etc.

This is a big step up from CA3’s **“Mongo as a StatefulSet inside a tiny cluster”** in terms of realistic architecture.

---

### 4️⃣ Operational Visibility and Scaling

* Prometheus + Loki + Grafana extended into this AWS-centric world gives:

    * Metrics for **Processor API, Kafka, Worker, DB**
    * Logs-in-context for debugging
* Components marked `<<scales>>` (Processor API, Kafka, Worker, monitoring stack) map naturally to **K8s Deployments/StatefulSets with HPAs**.

You still get the **“this actually scales under load”** narrative from CA3, but now in a multi-cloud setting.

---

## Updated Tradeoffs & Risks

### A. Reliability / HA

| Risk                                    | Why It Exists                                 | Impact                                        | Mitigation Path                                                                   |
| --------------------------------------- | --------------------------------------------- | --------------------------------------------- | --------------------------------------------------------------------------------- |
| Single-region DB and K3s                | CA4 is still a single-region design           | Region outage takes everything down           | Multi-AZ is a start; later CA (CA5?) can introduce multi-region or DR             |
| Self-managed Kafka on small K3s cluster | Educational choice to operate Kafka ourselves | Node or disk issues can cascade into downtime | Harden Kafka with PVs, multiple brokers, and KRaft; eventually consider MSK       |
| Bastion as single access choke point    | All admin/dev traffic goes through bastion    | Bastion failure = no easy ops access          | Add SSM Session Manager or a small HA bastion pattern; use IaaC for quick rebuild |

---

### B. Operations & Day-2 Concerns

| Issue                              | Cause                                   | Impact                                                                | Future Improvement                                                                                    |
| ---------------------------------- | --------------------------------------- | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| SSH tunnels are fragile            | Manual port mappings and user workflows | “It works on my laptop” but fails for others; confusing failure modes | Replace with WireGuard, AWS Client VPN, or SSM port forwarding; document a single blessed access path |
| Mixed managed & self-managed stack | DB managed, Kafka/K3s self-run          | Two very different ops models to understand                           | Over time, consolidate: either more managed (EKS/MSK) or fully self-run in a lab context              |
| Colab’s ephemeral nature           | Runtime resets & notebook disconnects   | Harder to run long-lived streaming tests from Colab                   | For persistent load testing, move producer to a dedicated container/Pod with same API contract        |

---

### C. Security

| Concern                                 | Reason                                             | Mitigation                                                                 |
| --------------------------------------- | -------------------------------------------------- | -------------------------------------------------------------------------- |
| SSH bastion as main gate                | Human accounts + SSH keys are a classic risk point | Use short-lived keys; enforce MFA; log and audit SSH usage                 |
| Kafka and K3s API reachable via bastion | Pivot risk if bastion is compromised               | Lock down SGs; use IAM + SSM; prefer console/SSM-based access over raw SSH |
| HTTP API auth from Colab                | Colab is off-VPC, over public internet or VPN      | Use API keys / tokens; enforce TLS, IP allowlists or VPN; rate limit       |

---

## Scalability Considerations

### Application / Compute

* **Processor API (Edge)**

    * Scales horizontally as a Deployment behind a Service/Ingress.
    * Good candidate for CPU/RPS-based HPA.

* **Kafka Brokers**

    * StatefulSet; scale by adding brokers and partitions (but more complex).
    * Current CA4 scope likely stays at 1–3 brokers.

* **Metadata Processor Workers**

    * Additional replicas improve throughput.
    * Better HPA signal: **Kafka lag** or consumer throughput rather than pure CPU.

### Data

* **DB**

    * Managed Mongo-compatible DB can scale vertically (instance size) and horizontally (read replicas).
* **S3**

    * Essentially unbounded; scale is mostly about organization and lifecycle policies.

### Observability

* Prometheus & Loki can become heavy as load/retention increases:

    * Path forward → offload to S3/Thanos or use partially managed solutions (Amazon Managed Grafana, AMP/AMG).

---

## Alternative Approaches

| Alternative                          | Strengths                                            | Drawbacks                                                    | When It Would Make Sense                                                       |
| ------------------------------------ | ---------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| **EKS + MSK + Atlas/DocumentDB**     | Strongly production-like; less ops toil              | More complex + more $$; less hands-on with cluster internals | When you want CA4 to be closer to a “production blueprint” than a teaching lab |
| **Single-cloud design (all on AWS)** | No cross-cloud networking; simpler routing           | Loses the interesting story of splitting GPU vs edge         | If cross-cloud networking is the main blocker/time sink                        |
| **No Kafka, just API -> DB**         | Simplest path for small volume; easy to reason about | Loses event semantics, replay, and CA2/CA3 lineage           | For a “minimal CA4” variant or a different assignment track                    |

---

## Hardening Roadmap (Beyond CA4)

1. **Promote K3s → EKS**

    * Managed control plane, cluster autoscaler, better lifecycle management.

2. **Harden Kafka**

    * Multi-broker, PV-backed, KRaft mode, TLS.
    * Optionally move to MSK while keeping app code unchanged.

3. **Strengthen Access Model**

    * Retire direct SSH bastion; move to SSM Session Manager, WireGuard, or Zero Trust access.

4. **Strengthen API Security**

    * Add authentication, rate limiting, and versioning around the Processor API.

5. **Expand Multi-Cloud Story**

    * Replace Colab with a more durable GPU workload (EKS managed node group or on-prem K3s w/ GPUs) while keeping the HTTP + Kafka + Worker + DB skeleton identical.