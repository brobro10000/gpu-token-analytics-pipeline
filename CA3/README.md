# 🧩 CA3 — Cloud-Native GPU Analytics Pipeline with Observability & Autoscaling

:contentReference[oaicite:1]{index=1}

## 📘 Summary

CA3 extends the CA2 GPU analytics pipeline by adding a **full observability stack**, **autoscaling**, and **log aggregation** on top of the existing **K3s** + **Kafka** + **Mongo** foundation.

New in CA3:
- **kube-prometheus-stack** (Prometheus Operator, Alertmanager, Grafana)
- **Loki + Promtail** for log aggregation
- **Autoscaling via HPA** (CPU-driven for Producers, optional for Processor)
- **Metrics exposed via starlette_exporter (/metrics)** for Processor
- Unified **Grafana dashboard** for pipeline throughput + system health

---

## 🧠 High-Level Architecture

* **Terraform** provisions:
  * AWS VPC, Security Groups, EC2 control-plane + workers
  * Outputs used to retrieve kubeconfig + join nodes

* **K3s** hosts three namespaces:
  * `platform` → **Kafka**, **Mongo**
  * `app` → **Processor**, **Producers** (+ HPA)
  * `monitoring` → **Prometheus Operator**, **Grafana**, **Loki**, **Promtail**

* **Data Flow**
```

Producers → Kafka → Processor → MongoDB

```

* **Observability**
```

Processor /metrics → Prometheus → Grafana Dashboards
Pod Logs → Promtail → Loki → Grafana Log Panels

````

---

## 📦 Container Registry Table

| Component | Registry / Image | Tag | Purpose |
|----------|-----------------|-----|---------|
| **Producers** | `ghcr.io/brobro10000/producers` | `ca3` | Generates GPU + token usage metrics and publishes to Kafka. |
| **Processor** | `ghcr.io/brobro10000/processor` | `ca3` | FastAPI consumer that writes to Mongo and exposes `/metrics`. |
| **Kafka** | `bitnami/kafka` | `3.6.1-debian-11-r1` | Message broker for streaming telemetry. |
| **MongoDB** | `mongo` | `7.0` | Persistent storage for metrics datasets. |

---

## 📋 Rubric Mapping — CA3 Evaluation Alignment

| Category | Weight | Evidence | Status |
|---------|--------|----------|--------|
| **1. Declarative Infrastructure** | 25% | Terraform for EC2 + SGs; K3s bootstrap automated; manifests under `k8s/*` | ✅ Fully Met |
| **2. Security & Access Controls** | 20% | No public workloads; kubeconfig restricted; SG allowlisting | ⚙️ Partial — Add NetworkPolicy + External Secrets for full credit |
| **3. Observability & Scaling** | 20% | kube-prometheus-stack + Loki; `/metrics` scraping; **HPA scaling** Producers | ✅ Fully Met |
| **4. Documentation & Architecture** | 25% | Architecture + Tradeoffs + Sequence diagrams + README | ✅ Fully Met |
| **5. Execution & Correctness** | 10% | End-to-end data flow verified; HPA scale-up/down demonstrated | ✅ Fully Met |

---

## 🏗️ Deployment Steps

### 1️⃣ Provision Infrastructure

```bash
cd CA3/terraform
make deploy         # terraform init + plan + apply
make outputs        # confirm cluster instance IPs
````

### 2️⃣ Bootstrap K3s + Fetch kubeconfig

```bash
cd CA3
make bootstrap-k3s
make status         # verify node Ready
```

Optional (if using private workers):

```bash
make join-workers
```

### 3️⃣ Install Observability Stack

```bash
make bootstrap-monitoring-prereqs   # installs Helm + metrics-server
make deploy-monitoring              # Prometheus + Grafana + Loki + Promtail
```

Access Grafana:

```bash
KUBECONFIG=.kube/kubeconfig.yaml kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
# login: admin / admin
```

### 4️⃣ Deploy Pipeline Workloads

```bash
make deploy       # applies Kafka + Mongo + Processor + Producers + HPA
make status       # confirm all pods Running
```

---

## 🔍 Verification

| Check                | Command                 | Expected                 |
| -------------------- | ----------------------- | ------------------------ |
| Kafka Ready          | `make verify-kafka`     | `1/1 Running`            |
| Mongo Ready          | `make verify-mongo`     | `1/1 Running`            |
| Processor Health     | `make verify-processor` | `/health` returns OK     |
| Producers Running    | `make verify-producers` | publishing logs visible  |
| End-to-End Data Flow | `make verify-workflow`  | Mongo counts increase    |
| Autoscaling          | `make verify-scale-hpa` | Producers scale out + in |

Monitor metrics:

```bash
# Prometheus targets
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
```

---

## 🧪 Example Log / Metric Checks

```bash
# Processor Logs
make K ARGS="-n app logs -l app=processor --tail=50"

# Mongo document count
make verify-deltas
```

---

## 📁 Directory Structure

```
CA3/
├── README.md
├── architecture.md
├── architecture-tradeoffs.md
├── conversation-summary.md
├── terraform/
├── Makefile
└── k8s/
    ├── platform/   # Kafka + Mongo
    ├── app/        # Processor + Producers + HPA
    └── monitoring/ # ServiceMonitors + dashboards
```

---

## 🎓 Demo Checklist (Fast)

| Step                         | Verified |
| ---------------------------- | -------- |
| Cluster Running              | ✅        |
| Kafka & Mongo Healthy        | ✅        |
| Processor Consuming          | ✅        |
| Producers Publishing         | ✅        |
| Prometheus Scraping /metrics | ✅        |
| Grafana Dashboard Populated  | ✅        |
| HPA Scales Producers         | ✅        |

---

## ✅ Completion Notes

CA3 successfully demonstrates:

* Distributed data pipeline
* Real-time ingestion & storage
* Full-stack observability (metrics + logs)
* Autoscaling tied to system demand

It prepares the environment for CA4, where durability, replication, and managed Kubernetes will be introduced.