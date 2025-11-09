# 🧩 CA3 — Cloud‑Native GPU Analytics Pipeline with Observability & Autoscaling

## 📘 Summary

CA3 extends the CA2 GPU analytics pipeline by adding a full **observability stack**, **autoscaling**, and **log aggregation** on top of the existing **K3s** + **Kafka** + **Mongo** foundation.

New in CA3:
- **kube-prometheus-stack** (Prometheus Operator, Alertmanager, Grafana)
- **Loki + Promtail** for log aggregation
- **Autoscaling via HPA** (CPU-driven for Producers; optional for Processor)
- **Metrics exposed via starlette_exporter (`/metrics`)** for Processor
- Unified **Grafana dashboards** for pipeline throughput + system health

Also see the CA3 section in the repository root README for a cohesive overview and quickstart: ../README.md

---

## 🧠 High‑Level Architecture

* **Terraform** provisions:
  * AWS VPC, Security Groups, EC2 control-plane + workers
  * Outputs used to retrieve kubeconfig + join nodes
* **Makefile** automates:
  * K3s bootstrap, kubeconfig retrieval, and worker joins
  * Monitoring stack install (Prometheus, Grafana, Loki, Promtail)
  * Kubernetes manifest deployment for platform + app layers
  * Verification commands and log tailing
* **K3s** hosts three namespaces:
  * `platform` → Kafka, MongoDB
  * `app` → Processor, Producers (+ HPA)
  * `monitoring` → Prometheus Operator, Grafana, Loki, Promtail
* **Data Flow**
```
Producers → Kafka → Processor → MongoDB
```
* **Observability**
```
Processor /metrics → Prometheus → Grafana dashboards
Pod logs → Promtail → Loki → Grafana log panels
```

---

## 📦 Container Registry Table

| Component       | Registry / Image                         | Tag  | Purpose                                                                      |
|-----------------|-------------------------------------------|------|------------------------------------------------------------------------------|
| **Producers**   | `ghcr.io/brobro10000/producers`           | `ca3`| Generates GPU + token usage metrics and publishes to Kafka.                  |
| **Processor**   | `ghcr.io/brobro10000/processor`           | `ca3`| FastAPI consumer that writes to Mongo and exposes `/metrics`.                |
| **Kafka**       | `bitnami/kafka`                           | `3.6.1-debian-11-r1` | Message broker for streaming telemetry.                        |
| **MongoDB**     | `mongo`                                   | `7.0`| Persistent storage for metrics datasets.                                     |

---

## 📋 Rubric Mapping — CA3 Evaluation Alignment

| Category                          | Weight | Evidence / Implementation Detail                                                                                                   | Status                                                         |
|-----------------------------------|--------|-------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------|
| **1. Declarative Infrastructure** | 25%    | Terraform for EC2 + SGs; declarative K3s bootstrap; Kubernetes manifests under `k8s/*`.                                        | ✅ Fully Met                                                    |
| **2. Security & Access Controls** | 20%    | No public workloads; kubeconfig restricted; SG allowlisting. NetworkPolicy + External Secrets recommended for full credit.     | ⚙️ Partial — Add NetworkPolicy + External Secrets for full marks |
| **3. Observability & Scaling**    | 20%    | kube-prometheus-stack + Loki; Processor `/metrics` scraping; **HPA** scales Producers; dashboards in Grafana.                   | ✅ Fully Met                                                    |
| **4. Documentation & Architecture**| 25%   | Architecture + tradeoffs + sequence diagrams; clear README with verification targets.                                           | ✅ Fully Met                                                    |
| **5. Execution & Correctness**    | 10%    | End-to-end data flow verified; HPA scale-out/in demonstrated.                                                                   | ✅ Fully Met                                                    |

---

## 🏗️ Replication Steps

### 1️⃣ Provision infrastructure (Terraform + Makefile)

```bash
cd CA3/terraform
make deploy         # terraform init + plan + apply
make outputs        # confirm cluster instance IPs
```

Notes:
- Override AWS profile/region as needed: `AWS_PROFILE=terraform AWS_REGION=us-east-1 make deploy`
- Provide an explicit EC2 keypair name if not set in tfvars: `SSH_KEY_NAME=my-key make deploy`

---

### 2️⃣ Bootstrap K3s + Fetch kubeconfig

```bash
cd CA3
make bootstrap-k3s   # installs K3s and fetches kubeconfig into CA3/.kube
make status          # verify control plane Ready
```

Optional (if using private workers):
```bash
make join-workers
```

---

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

Access Prometheus:
```bash
KUBECONFIG=.kube/kubeconfig.yaml kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
```

---

### 4️⃣ Deploy Pipeline Workloads

```bash
make deploy       # applies Kafka + Mongo + Processor + Producers + HPA
make status       # confirm all pods Running
```

---

## 🔍 Verification & Debugging

### 🌐 Check overall status
```bash
make status
```

### 🧩 Verify components
```bash
make verify            # runs verify-kafka, verify-mongo, verify-processor, verify-producers
make verify-workflow   # end-to-end: baseline→nudge→delta checks
```

Or individually:
```bash
make verify-kafka
make verify-mongo
make verify-processor
make verify-producers
make verify-scale-hpa   # demonstrates autoscaling
```

Each verify command:
- Shows pod + service info
- Tails logs
- Confirms resource readiness

### 🪵 Logs
```bash
make K ARGS="-n platform logs -l app=kafka --tail=100"
make K ARGS="-n app logs -l app=processor --tail=100"
make K ARGS="-n monitoring logs -l app.kubernetes.io/name=loki --tail=100"
```

---

## ⚙️ Common Issues

| Component            | Symptom                         | Likely Fix                                                                                         |
|----------------------|----------------------------------|-----------------------------------------------------------------------------------------------------|
| **Kafka**            | `0/1` Ready                      | Ensure headless Service exists; check advertised listeners; allow plaintext in dev.                 |
| **Processor**        | `ImagePullBackOff`               | Verify image path + `imagePullSecrets`; check `KAFKA_BOOTSTRAP` and `MONGO_URL`.                    |
| **Producers**        | `CrashLoopBackOff`               | Confirm Kafka DNS resolves; ensure resource requests set for HPA to function.                      |
| **Mongo**            | `CrashLoopBackOff`               | Ensure volume mount works; check logs for storage issues.                                           |
| **Prometheus**       | Targets Down / empty metrics     | Verify ServiceMonitor selectors; ensure Processor exposes `/metrics`; check port-forwarding.        |
| **Grafana**          | Cannot login/empty dashboards    | Use `admin/admin` on first run; verify Prometheus datasource; import dashboards if needed.          |
| **Loki/Promtail**    | No logs in Grafana               | Ensure Promtail DaemonSet running; check label selectors; verify Loki service is reachable.         |
| **HPA**              | No scaling activity               | Confirm metrics-server installed; set CPU requests/limits; check HPA target utilization thresholds. |

---

## 🧪 Manual Debug Commands

```bash
# Nodes
KUBECONFIG=.kube/kubeconfig.yaml kubectl get nodes -o wide

# Watch rollout
make K ARGS="-n app rollout status deploy/processor -w"

# Inspect services
make K ARGS="-n monitoring get svc -o wide"

# Check HPA state
make K ARGS="-n app get hpa"
make K ARGS="-n app describe hpa producers"
```

---

## 📊 Validation Checks

| Step                     | Command                                | Expected Result                |
|--------------------------|----------------------------------------|--------------------------------|
| Cluster up               | `make status`                          | Control plane Ready            |
| Kafka ready              | `make verify-kafka`                    | 1/1 Running                    |
| Mongo ready              | `make verify-mongo`                    | 1/1 Running                    |
| Processor running        | `make verify-processor`                | `/health` OK; `/metrics` scraped |
| Producers running        | `make verify-producers`                | Publishes to Kafka             |
| End-to-end data flow     | `make verify-workflow`                 | Mongo counts increase          |
| Autoscaling              | `make verify-scale-hpa`                | Producers scale out and in     |

---

## 📁 Repo Structure

```
CA3/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── architecture-tradeoffs.md
│   ├── conversation-summary.md
│   ├── SLI.md
│   └── SLO.md
├── diagrams/
│   ├── architecture.puml
│   └── provisioning-sequence-final.puml
├── screenshots/
│   ├── deploy-all-monitoring-stack.png
│   ├── make status with monitoring.png
│   ├── prometheus-query-up.png
│   ├── prometheus-query-up-visualization.png
│   ├── prometheus-alerts.png
│   ├── tunnel prometheus.png
│   └── tunnel grafana.png
├── Makefile
├── k8s/
│   ├── platform/
│   │   ├── kafka/
│   │   └── mongo/
│   ├── app/
│   │   ├── processor/
│   │   └── producers/
│   └── monitoring/
│       └── service-monitoring/
└── terraform/
    ├── Makefile
    ├── providers.tf
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── modules/
        ├── vpc/
        ├── security_groups/
        ├── network/
        ├── cluster/
        │   └── templates/
        └── instances/
            └── templates/
```

---

## 🎓 Grading / Demo Checklist

| Category                          | Deliverable                                              | Validation                                         |
|-----------------------------------|----------------------------------------------------------|----------------------------------------------------|
| **1. Infrastructure (Terraform)** | AWS EC2 cluster provisioned with observability-ready K3s | `make deploy` + `make bootstrap-k3s`               |
| **2. Monitoring Stack**           | Prometheus + Grafana + Loki + Promtail installed         | `make deploy-monitoring` + port-forwards work      |
| **3. Namespaces**                 | `app`, `platform`, `monitoring` created                  | `kubectl get ns`                                   |
| **4. Platform Layer**             | Kafka + Mongo deployed                                   | `make verify-kafka`, `make verify-mongo`           |
| **5. App Layer**                  | Processor + Producers + HPA                              | `make verify-processor`, `make verify-producers`   |
| **6. Observability**              | Processor `/metrics` scraped; dashboards populated       | Prometheus targets Up; Grafana shows dashboards    |
| **7. Autoscaling**                | HPA scales Producers                                     | `make verify-scale-hpa`                            |
| **8. Debug**                      | Logs visible in Grafana (Loki)                           | `grafana-loki-data` screenshot                     |
| **9. Automation**                 | Makefile executes full workflow                          | `make deploy`, `make verify`, `make verify-workflow` |
| **10. Documentation**             | Clear README with setup + results                        | ✅ This file                                        |

---

## 📎 Related Docs

* [docs/architecture.md](./docs/architecture.md) — Updated CA3 cluster, namespaces, and observability diagram
* [docs/architecture-tradeoffs.md](./docs/architecture-tradeoffs.md) — Reasoning and future evolution
* [docs/conversation-summary.md](./docs/conversation-summary.md) — Evolution of CA3
* [docs/SLI.md](./docs/SLI.md) — Service Level Indicators for CA3
* [docs/SLO.md](./docs/SLO.md) — Service Level Objectives for CA3

---

## 📸 Screenshots (by command order)

- Deploy observability stack
  
  ![deploy monitoring](screenshots/deploy-all-monitoring-stack.png)

- Cluster status with monitoring
  
  ![make status with monitoring](screenshots/make%20status%20with%20monitoring.png)

- Port-forward Prometheus
  
  ![tunnel prometheus](screenshots/tunnel%20prometheus.png)

- Port-forward Grafana
  
  ![tunnel grafana](screenshots/tunnel%20grafana.png)

- Prometheus query: `up`
  
  ![prometheus query up](screenshots/prometheus-query-up.png)

- Prometheus `up` query visualization
  
  ![prometheus query up visualization](screenshots/prometheus-query-up-visualization.png)

- Prometheus Alerts
  
  ![prometheus alerts](screenshots/prometheus-alerts.png)

- Grafana Loki shows log data
  
  ![grafana loki data](screenshots/grafana-loki-data.png)