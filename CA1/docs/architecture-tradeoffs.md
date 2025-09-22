# Architectural Tradeoffs

This CA1 design intentionally uses **Terraform + cloud-init + Docker Compose on EC2** (no Ansible, no managed Kafka/Mongo, no Kubernetes yet). Here’s what that buys us—and what it costs—along with why this is a good bridge to Kubernetes later.

## Why Terraform-only now

* **Skill building for K8s:** Terraform is the lingua franca for provisioning clusters, node groups, load balancers, IAM, and service accounts. Getting fluent here directly transfers to creating EKS/GKE and wiring IRSA, VPC CNI, etc.
* **Single tool, clear boundaries:** Terraform handles infra; **cloud-init** handles bootstrap. Fewer moving parts than adding a second config tool (Ansible) for this POC.
* **Deterministic provisioning:** `user_data_replace_on_change` + idempotent scripts keep bring-up repeatable without maintaining golden AMIs yet.

**Tradeoff:** Terraform isn’t a configuration drift manager. Cloud-init is “fire-and-forget,” so post-boot drift isn’t automatically reconciled (unlike a daemonized CM tool or Kubernetes controllers).

---

## EC2 + Compose vs Managed Services & Kubernetes

**Pros**

* **Maximum visibility:** You see every layer (security groups, ports, images, volumes), which is great for learning and debugging.
* **Lightweight:** Compose is sufficient for a 4-VM POC; no cluster control plane to learn right now.
* **Cost control:** Small t3.\* instances; no MSK/EKS control-plane fees.

**Cons**

* **No HA:** Single-broker Kafka and single Mongo node mean no quorum, no automated failover, limited durability guarantees.
* **Scaling limits:** Horizontal scaling, rolling updates, and self-healing are manual with Compose.
* **Ops toil:** Log aggregation, metrics, TLS, and secrets rotation are DIY.

**K8s path (future)**

* Migrate VM3/VM4 to **containers on EKS** (Terraform still provisions EKS).
* Use **Helm** or **Kustomize** for app lifecycles; adopt **HPA** for scaling and **readiness/liveness** probes instead of Compose healthchecks.
* Move Kafka/Mongo to **managed services** (MSK, Atlas/DocumentDB) or run operators on K8s if you need to self-host.

---

## Build-from-Git on instance vs Prebuilt images

**Current choice:** Build images on each VM at boot from a Git subdirectory.

**Pros**

* **Zero CI/CD setup:** Instances always build from the repo state (ref/path pinned), guaranteeing code parity with this POC.
* **No artifact registry required:** Avoids ECR/Docker Hub auth and lifecycle.

**Cons**

* **Slower cold starts:** Full image build on first boot; sensitive to network and Git availability.
* **Security & reproducibility:** Pulling and building at boot relies on the branch ref; less traceable than immutable, signed images.
* **Cache loss:** Each VM builds alone with minimal caching.

**Alternative (recommended later):** CI builds tagged images → push to **ECR** → instances **pull** pinned digests. Faster, auditable, and reproducible.

---

## Bind mounts vs Named volumes (state)

**Kafka:** Bind mount required a host-UID fix (Bitnami runs as 1001).
**Mongo:** Switched to **named volume** to avoid host permission issues.

**Tradeoff:** Named volumes reduce permission pain but make on-host inspection less convenient. For prod, externalize data to managed services or at least add backups/snapshots.

---

## Secrets & configuration

**Current POC:** No DB auth; no secrets distributed. All **runtime values** (IPs, ports, topics, DB name, image tags) are **parameterized** via Terraform/cloud-init—nothing hardcoded.

**Pros**

* Clear demonstration of “no hardcoded env values.”
* Simpler bootstrap; fewer moving parts.

**Cons**

* If/when you enable auth, you’ll need a secrets path (AWS Secrets Manager/SSM + **EC2 instance profiles** or, on K8s, **IRSA** + Secret/External Secrets).
* Without a secrets manager, rotation/audit aren’t addressed.

---

## Security groups & networking

**Pros**

* **Least-privilege SGs:** Kafka only from producers/processor; Mongo only from processor; Processor API only from admin CIDR.
* **No data plane exposed to the public Internet.**

**Cons**

* No mTLS/encryption-in-transit yet.
* Manual SG wiring can be error-prone (we added verify targets with `nc` to catch it).

**Future:** TLS on Kafka/Mongo or service mesh mTLS on K8s; private subnets with NAT/bastion; ALB/NLB for ingress where appropriate.

---

## Observability & operability

**Current:** Compose healthchecks + ad-hoc `docker logs`/`journalctl`; Makefile verify targets for deterministic checks.

**Tradeoff:** Great for a POC, but you’ll want:

* Centralized logs (CloudWatch Logs driver/Fluent Bit).
* Metrics (Prometheus/Grafana) and tracing (OpenTelemetry).
* Alerting (CloudWatch or Grafana Alerting).

---

## Image vs Instance immutability

* **Now:** Mutable VMs with cloud-init scripts. Simple and flexible for learning.
* **Tradeoff:** Longer boot, more variance across runs.

**Future:** Bake **golden AMIs** with Packer (or just move to **immutable containers on EKS**). Faster, more predictable rollouts.

---

## Cost & simplicity

* **Pros:** t3.small/t3.micro keep spend down; no control-plane fees.
* **Cons:** You manage patching and lifecycle; managed offerings would offload ops but cost more.

---

## Bottom line

Choosing **Terraform-only** for CA1 keeps the toolchain small, maximizes learning in the layers you’ll reuse for Kubernetes (IAM, networking, state, parameterization), and stays faithful to the assignment’s IaC focus. The deliberate compromises—single-node services, Compose instead of K8s, build-on-instance, and no secrets manager—are sensible for a graded POC and provide a clear migration path to **EKS + managed data services** when you’re ready.
