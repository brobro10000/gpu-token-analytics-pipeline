# Architecture Tradeoffs — CA2 (Terraform + K3s on AWS)

## Executive Summary

| Choice                                   | Why We Chose It                                          | Pros                                                                          | Cons / Risks                                                               | Near-Term Scale Path                                                                  |
| ---------------------------------------- | -------------------------------------------------------- | ----------------------------------------------------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **Self-managed K3s on EC2 (Terraform)**  | Full control, lower cost, rapid bootstrap                | Reproducible IaC; minimal control-plane overhead; excellent learning fidelity | Operational burden (patches, CA, metrics, upgrades); no cluster autoscaler | Add workers; integrate Prometheus + HPA; migrate to **EKS** for managed control plane |
| **Public IP kubeconfig (CA embedded)**   | Fixes TLS verification; no SSH tunnel dependency         | Works locally with `kubectl` directly; reproducible                           | Still exposes API via SG allowlist; must maintain SANs                     | Replace with Bastion/VPN or `aws_lb` ingress proxy                                    |
| **Static YAML metrics-server**           | Independence from K3s default; reproducible via Makefile | Deterministic setup; explicit RBAC; debuggable                                | Manual version management; must tune flags per environment                 | Move to Helm chart in Terraform with version pinning                                  |
| **Single-replica Kafka & Mongo**         | MVP speed and cost efficiency                            | Lightweight footprint; fewer moving parts                                     | No HA or durability; single point of failure                               | Add PVCs + multi-replica (3× Kafka KRaft, 3× MongoRS)                                 |
| **Ephemeral storage (`emptyDir`)**       | Fast iteration; no StorageClass needed                   | Zero configuration; instant cleanup                                           | Data loss on node reschedule; non-persistent                               | Introduce **EBS StorageClass** + `volumeClaimTemplates`                               |
| **Continuous Producers (looped Python)** | Required for sustained HPA metrics                       | Keeps pod active; visible CPU utilization                                     | Manual wrapping of script; may busy-loop                                   | Replace with native daemon mode or sidecar driver                                     |
| **Makefile automation**                  | Unified developer UX across bootstrap + verify           | One-command reproducibility; clear separation of concerns                     | Local coupling; hidden assumptions                                         | Add CI wrappers (`make verify-all` in GitHub Actions)                                 |

---

## Goals & Assumptions

* Showcase **IaC, cluster bootstrap, and app deployment** end-to-end.
* Maintain **low cloud cost** (no managed control plane or HA services).
* Optimize for **debuggability, transparency, and learning value**, not production hardening.

---

## Benefits

### 1️⃣ Reproducibility & Control

* Terraform defines network + instance topology and outputs dynamic IPs for the Makefile.
* K3s provides a lightweight binary for quick re-deployments.
* Makefile standardizes every phase: `bootstrap`, `deploy`, `verify-*`, `status`.

### 2️⃣ Cost Efficiency

* EC2 instances only; no EKS or managed service charges.
* Default `t3.small`/`t3.medium` SKUs are sufficient for workloads and autoscale tests.

### 3️⃣ Observability & Debuggability

* Metrics-server deployed manually with explicit RBAC enables controlled metrics flow.
* Make targets (`verify-*`) expose pipeline health through Mongo deltas and logs.

---

## Updated Tradeoffs & Risks

### A) Reliability / HA

| Risk                          | Context                 | Mitigation                                        |
| ----------------------------- | ----------------------- | ------------------------------------------------- |
| **Single Kafka / Mongo node** | No quorum or redundancy | Add PVCs and multi-replica StatefulSets (3× each) |
| **`emptyDir` persistence**    | Data lost on restart    | Use EBS PVCs with retention policies              |
| **No Cluster Autoscaler**     | Worker capacity fixed   | Add node group management or migrate to EKS       |

---

### B) Operations / Day-2 Lifecycle

| Issue                                   | Impact                    | Mitigation                                         |
| --------------------------------------- | ------------------------- | -------------------------------------------------- |
| Manual patching of K3s & metrics-server | CVE exposure              | Integrate Helm-based upgrade pipeline              |
| TLS & SAN friction                      | Causes x509 errors        | Automate kubeconfig generation with CA embedding   |
| No auto-backup                          | Data loss on node failure | Schedule `kubectl cp` + `mongodump` jobs or Velero |

---

### C) Security

| Concern                      | Reason                             | Mitigation                                                  |
| ---------------------------- | ---------------------------------- | ----------------------------------------------------------- |
| Kafka and Mongo in plaintext | Simplicity for CA2 MVP             | Add TLS or place behind a service mesh (Linkerd/Istio)      |
| Secrets in plaintext         | No external secret integration yet | Use **External Secrets Operator** + AWS SSM/Secrets Manager |
| Open SG ports                | Public control plane               | Restrict ingress to known IPs or private subnets            |

---

### D) Developer Ergonomics

| Issue                               | Description               | Fix                                                     |
| ----------------------------------- | ------------------------- | ------------------------------------------------------- |
| Curl missing in base images         | Healthcheck scripts fail  | Use `wget` or ephemeral curl pod (`curlimages/curl`)    |
| One-shot producers exit             | HPA sees no load          | Loop Python producer for continuous metrics             |
| Kafka advertised listeners mismatch | Connection refused errors | Set `PLAINTEXT://kafka.platform.svc.cluster.local:9092` |
| Reprovision friction                | Manual cleanups           | Add `make destroy-all` for Terraform + K3s teardown     |

---

## Scalability Considerations

### Cluster

* **Vertical:** Scale instance size (vCPU/mem).
* **Horizontal:** Add EC2 workers; re-register with control plane.
* **Future:** Migrate to **EKS** for managed API server, Cluster Autoscaler, and IAM roles for service accounts (IRSA).

### Data Plane

* **Kafka:** Move to 3-node KRaft with persistent storage and rack awareness.
* **Mongo:** ReplicaSet + PVs; auth enabled; automated backup pipeline.

### Application Layer

* **Producers:** Scale via HPA using CPU utilization (validated post-metrics fix).
* **Processor:** Add concurrency pool; integrate readiness/liveness probes.
* **Verification:** Parameterize Makefile for burst load and expected Mongo deltas.

---

## Alternatives & Evaluation

| Option                    | Pros                                                   | Cons                                    | Ideal Use                                 |
| ------------------------- | ------------------------------------------------------ | --------------------------------------- | ----------------------------------------- |
| **EKS**                   | Managed HA control plane; autoscaling; IAM integration | Higher cost; extra Terraform complexity | When cluster stability > cost priority    |
| **Managed Kafka / Atlas** | Offloads ops; HA & SLA                                 | Vendor lock-in; monthly fees            | When persistence and uptime are essential |
| **Pure VM (CA1 style)**   | Simple mental model                                    | No orchestration; manual scaling        | Micro PoCs or early labs                  |

---

## Cost Outlook

| Phase              | Expected Cost           | Notes                                        |
| ------------------ | ----------------------- | -------------------------------------------- |
| **CA2**            | ≈ $10–15/day (EC2 only) | 2–3 EC2 nodes, small instance types          |
| **CA3+**           | ≈ $70–100/mo + storage  | Adds EKS control plane, managed Kafka/Mongo  |
| **Managed Future** | Variable                | Higher reliability and security offset costs |

---

## Hardening Roadmap

1. **Storage Durability:** Introduce EBS StorageClass + PVCs (Kafka/Mongo).
2. **HA Topology:** Expand to 3× brokers + 3× replica sets; add PDBs.
3. **Security:** TLS/mTLS across data plane; NetworkPolicies; Secrets Manager.
4. **Observability:** Deploy Prometheus + Grafana + Loki via Helm.
5. **CI/CD Integration:** Automated `verify-all` Make target in GitHub Actions.
6. **Platform Evolution:** Evaluate EKS migration and managed data backends.

---

## Bottom Line

The CA2 design balances **educational transparency**, **cost efficiency**, and **operational realism**.
It now includes:

* A **deterministic bootstrap** process (Terraform + Makefile)
* **Manual metrics-server deployment** with working metrics and HPA readiness
* **Continuous producers** for steady workloads
* **Kafka connectivity fixes** and **Mongo verification**
* Secure, debuggable configuration flows (public IP + CA-embedded kubeconfig)

While intentionally **non-HA** and **manually operated**, it defines a clear upgrade path toward production-grade Kubernetes on **EKS** with persistent storage, secrets management, and scalable observability.
