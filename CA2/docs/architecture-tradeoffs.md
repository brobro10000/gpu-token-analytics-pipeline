# Architecture Tradeoffs — CA2 (Terraform + K3s on AWS)


## Executive Summary

| Choice                                          | Why we chose it                           | Pros                                                                   | Cons / Risks                                                                      | Near-term Scale Path                                                   |
| ----------------------------------------------- | ----------------------------------------- | ---------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| **Self-managed K3s on EC2 (via Terraform)**     | Full control, low cost, fast bootstrap    | Reproducible infra; minimal control-plane overhead; great for learning | You own control-plane ops; fewer guardrails vs managed K8s; no cluster autoscaler | Add workers; tune K3s; eventually migrate to **EKS**                   |
| **SSH tunnel to API (127.0.0.1:6443)**          | Avoid opening 6443 on the Internet        | Simple, secure dev access                                              | Requires a running tunnel; TLS/kubeconfig fiddly                                  | Replace with public-IP SAN + SG allowlist or private bastion/VPN       |
| **Single-replica Kafka & Mongo (StatefulSets)** | MVP speed and cost                        | Easy to run; low resource footprint                                    | No HA, no quorum; ephemeral by default                                            | Add PVCs + multi-replica (3x Kafka KRaft, 3x MongoRS)                  |
| **Ephemeral storage (`emptyDir`)**              | Fast iteration; no storage classes needed | Zero setup; cleans on pod reschedule                                   | Data loss on reschedule/reboot; no backups                                        | EBS-backed **StorageClass** + `volumeClaimTemplates`                   |
| **Makefile automation**                         | One-command ergonomics                    | Lower toil; consistent ops across devs                                 | Local environment coupling; easy to drift                                         | CI job wrappers; `terraform validate`/`kubectl apply --server-dry-run` |

---

## Goals & Assumptions

* Teach/validate **IaC, cluster bring-up, and app deployment** end-to-end.
* Keep costs minimal; accept **non-HA** posture for the assignment.
* Prioritize **clarity and debuggability** over production hardening.

---

## Benefits

### 1) Reproducibility & Control

* **Terraform** defines VPC, SGs, EC2, and outputs → repeatable environments.
* **K3s** is lightweight; single binary server/agent simplifies bootstrap.
* **Makefile** provides idempotent verbs (`bootstrap`, `deploy`, `verify-*`, `status`).

### 2) Cost Efficiency

* No managed control-plane fees (vs EKS). Small instance types suffice for MVP.

### 3) Learning Value

* Exposes the real layers: security groups, kube API flows, headless Services, StatefulSets, probes, etc.

---

## Tradeoffs & Risks

### A) Reliability / HA

* **Single broker** Kafka & **single node** Mongo → no quorum or failover.
* `emptyDir` means **state loss** on pod reschedule or node failure.

**Mitigations (short-term)**

* Use **EBS-backed PVCs**.
* Increase replicas; add **PodDisruptionBudgets**, **pod anti-affinity**, **readiness/liveness** probes.

**Mitigations (long-term)**

* Use managed data planes (**MSK**, **MongoDB Atlas/DocumentDB**) or operators (**Strimzi**, MongoDB Community).

### B) Operations / Day-2

* You own patching of OS, K3s, and addons.
* TLS/Kubeconfig friction (tunnel vs public IP SAN) can surprise new users.
* No built-in autoscaling/cluster autoscaler; capacity is manual.

**Mitigations**

* Add **prometheus-stack** (kube-prometheus), **Grafana**, and **Loki/Fluent Bit**.
* Integrate **Cluster Autoscaler** (if moving to EKS) and HPA for app pods.
* Bake a **golden AMI** (Packer) to speed replacements.

### C) Security

* Kafka runs **PLAINTEXT** for MVP; no mTLS, no auth on Mongo.
* Secrets are likely plain K8s `Secret` or env vars in this phase.

**Mitigations**

* Use **External Secrets Operator** (with AWS Secrets Manager/SSM Parameter Store).
* Enable **TLS** on Kafka/Mongo or terminate via a service mesh (Linkerd/Istio) with mTLS.
* Restrict egress with **NetworkPolicies**.

### D) Developer Ergonomics

* SSH tunnel requirement adds a step; kubeconfig rewrites can drift.
* Make targets assume project layout and local tools.

**Mitigations**

* Add **background tunnel targets** (`tunnel-up`/`tunnel-down`).
* Provide a `make k` wrapper and CI checks to standardize versions.

---

## Scalability Considerations

### Cluster Scale

* **Vertical**: bump instance types (memory/CPU).
* **Horizontal**: add nodes; schedule app pods with resource requests/limits.
* Migrate to **EKS** for **managed control plane** and **Cluster Autoscaler**, node groups, and IRSA.

### Data Plane Scale

* **Kafka**: move to **3-node KRaft**; use persistent volumes; set `KAFKA_CFG_CONTROLLER_QUORUM_VOTERS` correctly; enable **rack awareness** and **PDBs**.
* **Mongo**: adopt **ReplicaSet (3x)** with PVs; enable **auth**; backup/restore (e.g., Velero, snapshots).

### App Layer

* Add **HPA** for Producers; use **Requests/Limits**; rollout strategies; health endpoints.
* Introduce **Kustomize/Helm** for configuration overlays (dev/stage/prod).

---

## Alternatives We Considered

| Option                                    | Pros                                            | Cons                                | When to choose                     |
| ----------------------------------------- | ----------------------------------------------- | ----------------------------------- | ---------------------------------- |
| **EKS (managed K8s)**                     | HA control plane, ecosystem tooling, autoscaler | Higher cost/complexity upfront      | Teams ready for production posture |
| **Managed Kafka + Atlas/DocumentDB**      | Offloads ops; strong SLAs                       | Vendor lock-in; cost                | When data durability is a must     |
| **Pure VMs + Docker Compose (CA1 style)** | Simpler mental model; no Kubernetes             | Hard to scale, manual orchestration | Tiny POCs, single node services    |

---

## Cost Outlook

* **Current**: EC2 instances + EBS (if added); no control-plane fee; minimal data transfer.
* **Future**: EKS adds ~$70–$80/mo control-plane per cluster (region-dependent). Managed data services add per-hour + storage + I/O costs—traded for reduced ops toil and higher SLOs.

---

## Concrete Hardening Roadmap

1. **Storage**: introduce EBS StorageClass + PVCs for Kafka/Mongo; scheduled backups.
2. **Resilience**: scale to **3x** Kafka + **3x** Mongo; PDBs, anti-affinity, readiness/liveness.
3. **Security**: secrets via AWS SM/SSM + External Secrets; TLS/mTLS; NetworkPolicies.
4. **Observability**: kube-prometheus-stack; Loki/Fluent Bit; dashboards & alerts.
5. **Delivery**: CI builds to **ECR**; `imagePullSecrets`; pinned digests; `imagePullPolicy: IfNotPresent`.
6. **Platform**: evaluate **EKS** with node groups and Cluster Autoscaler when steady-state workloads grow.

---

## Bottom Line

This CA2 architecture optimizes **learning, speed, and cost** while delivering a fully automated cluster and platform/app workloads. The tradeoff is accepting **non-HA** components and some **operational toil**. The design makes the **upgrade path clear**: add PVCs and replicas for immediate resilience; adopt managed services or move the control plane to **EKS** for sustainable scale and SLOs.
