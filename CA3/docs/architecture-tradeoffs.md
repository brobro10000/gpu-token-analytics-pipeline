# Architecture Tradeoffs — CA3 (K3s + Kafka + Mongo + Observability + Autoscaling)

:contentReference[oaicite:1]{index=1}

## Executive Summary

| Choice | Why We Chose It | Pros | Cons / Risks | Future Scale Path |
|-------|----------------|------|--------------|------------------|
| **Self-managed K3s on EC2 (Terraform)** | Maintain continuity with CA2 while extending into Observability & HPA | Low control-plane overhead, fast provisioning, strong learning value | Operational overhead (patching, recovery, CA rotation), no cluster autoscaler | Migrate to **EKS** to reduce operational toil and improve node lifecycle management |
| **Kafka + MongoDB as StatefulSets** | Match CA2’s data pipeline but containerized under Kubernetes | Uniform deployment model; observable; testable under failure | Single-node Kafka & Mongo → **no durability**; restart events drop state | StatefulSets + PVs → multi-broker Kafka (3×) & Mongo ReplicaSet (3×) |
| **starlette_exporter for Processor metrics** | Lightweight, Python-native Prometheus endpoint | Easy to integrate; good visibility into app throughput & error rate | Limited defaults → custom metrics must be defined manually | Introduce structured metrics (histograms, percentiles), Kafka Lag Exporter |
| **kube-prometheus-stack + Loki/Promtail** | Single Helm stack delivers metrics, dashboards, alerts, logs | One consistent monitoring system, Grafana dashboards, logs-in-context | Resource overhead; CRDs add complexity; can “hide” failure behind dashboards | Move storage to S3/Thanos for long-term metrics retention |
| **HPA Autoscaling (CPU-based)** | Demonstrate dynamic scaling in response to load | Clear visibility of scaling behavior and node resource usage | CPU ≠ business throughput; can scale incorrectly under I/O-bound loads | Introduce scaling on **Kafka Lag** or **custom Processor queue metrics** |
| **Single VPC, no ingress, cluster private** | Keep blast radius small and avoid public attack surface | Safe default, minimal SG exposure | No external UI access without port-forward | Introduce Traefik ingress + cert-manager for TLS |

---

## Goals & Assumptions

* Extend CA2 pipeline into **observability, scaling, and logging**, not just raw deployment.
* Preserve **low cloud costs** by **not** introducing managed services yet.
* Optimize for **debuggability, transparency, and self-awareness** of the system’s data flow.
* Durability and HA are *intentionally not primary goals* in CA3 (will be addressed in CA4/EKS transition).

---

## Benefits

### 1️⃣ End-to-End Operational Observability
We now have:
- Metrics at node, pod, and application level
- Request latency and failure visibility from Processor
- Token & GPU metrics flowing through pipeline into persistent storage
- Log context correlation in Grafana via Loki

This enables **root cause analysis** without SSH or guesswork.

### 2️⃣ Reproducible, Declarative, Single-Command Deployments
Everything from:
- Bootstrap → Monitoring → App Stack → Validation  
is automated via **Makefile + Terraform output introspection**.

### 3️⃣ Demonstrates Real Cluster Behavior Under Load
The autoscaling test (`make verify-scale-hpa`) makes CA3 an actual **performance experiment**, not just a static deployment.

---

## Updated Tradeoffs & Risks

### Reliability / HA

| Risk | Why It Exists | Impact | Mitigation Path |
|------|--------------|--------|----------------|
| Single-replica Kafka & Mongo | Chosen for simplicity & cost | Broker/DB loss takes pipeline down | Multi-node STS + PVCs + anti-affinity |
| Ephemeral data (emptyDir) | Fast iteration environment | Data loss on node reschedule | Introduce EBS-backed StorageClass |
| No cluster autoscaler | K3s self-managed control-plane | Scaling stops at node limits | On migration to EKS: enable CA + Karpenter |

---

### Operations & Day-2 Concerns

| Issue | Cause | Impact | Future Improvement |
|------|-------|--------|-------------------|
| Helm chart upgrades require care | CRDs change frequently | Silent monitoring failures if versions drift | Pin versions, test CRD diff before upgrade |
| Loki logs retention is local | No object storage backend | Limited log history | Add S3 + retention policies |
| Kafka/Zookeeper logging noisy | Stateful workloads log aggressively | Harder to parse logs manually | Use log labels & Grafana log queries |

---

### Security

| Concern | Reason | Mitigation |
|--------|--------|------------|
| Kafka/Mongo run in plaintext | Simplicity over transport security | Introduce TLS sidecars or Linkerd mTLS |
| Secrets stored in K8s directly | Default K8s secret storage is base64 only | Use **External Secrets Operator + AWS SSM/Secrets Manager** |
| Control plane reachable via SG allowlist | Convenience for kubectl access | Replace with WireGuard/Bastion/SSM session |

---

## Scalability Considerations

### Application Scaling
- **Producers** scale reliably under CPU-driven HPA.
- **Processor** can be scaled when consumer throughput drops or queue lag appears.
- **Better scaling signal** is **Kafka Consumer Lag**, not CPU.

### Data Scaling
- Kafka → move from 1 broker → 3 broker KRaft mode.
- Mongo → migrate to **ReplicaSet** with PVs.

### Metrics Scaling
- Prometheus → may require **Thanos** sidecar for long-term retention and query federation.

---

## Alternative Approaches (With Tradeoffs)

| Alternative | Strengths | Drawbacks | Appropriate When |
|------------|-----------|-----------|-----------------|
| **EKS + MSK + Atlas** | Fully managed data plane & control plane | $$$ and less hands-on operations | Production or long-running lab |
| **Docker Compose / Bare VMs** | Lower cognitive complexity | No autoscaling, no scheduling | Early development teaching |
| **Nomad instead of K8s** | Simpler orchestrator | Less ecosystem support | Highly homogenous workloads |

---

## Cost Outlook (Approx.)

| Item | Rate | Notes |
|------|------|------|
| EC2 t3.small × 2–3 nodes | Lowest cost | Tight resource envelope for Prometheus |
| CPU load tests (burst scaling) | Temporary spend increase | Use `make verify-scale-hpa` sparingly |
| Monitoring stack retention | Affects disk + storage | Move to S3 if logs/metrics retained long-term |

---

## Hardening Roadmap (CA4+)

1. **Migrate to EKS** for autoscaler + managed control plane.
2. **Enable multi-broker Kafka** + persistent storage.
3. **Enable Mongo ReplicaSet** for read scalability + reliability.
4. **Implement mTLS** (Linkerd minimal mesh).
5. **Scale dashboards** with custom latency & throughput SLO panels.

---

## Bottom Line

CA3 intentionally favors:
**Learning value + Observability clarity + Real scaling behavior**
over
**Durability + HA + Production readiness**.

It successfully demonstrates:
- Streaming data pipeline
- Distributed processing and storage
- System introspection through metrics + logs
- Autoscaling in response to load

while keeping a clear and achievable path toward **production-grade** evolution in CA4.