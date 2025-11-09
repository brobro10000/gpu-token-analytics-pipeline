## CA3 Conversation Summary

### Objective
Design, deploy, and validate a distributed GPU + token usage telemetry pipeline running on a K3s cluster provisioned on AWS EC2. The system must:
- Ingest workload metrics and token usage events from producers.
- Stream through Kafka.
- Process and store metrics in MongoDB via a FastAPI processor service.
- Autoscale producers (and optionally processor) based on observed CPU load.
- Provide operational observability via Prometheus, Grafana, Loki, and Promtail.
- Define measurable SLIs/SLOs/SLAs for reliability and reporting.

---

### Core Components (as deployed)
| Component | Namespace | Type | Notes |
|----------|-----------|------|-------|
| Kafka | `platform` | StatefulSet | Serves as message broker for metric + token usage streams. |
| MongoDB | `platform` | StatefulSet | Stores gpu_metrics, token_usage documents. |
| Processor | `app` | Deployment | FastAPI + Kafka consumer + Mongo writer + Prometheus metrics. |
| Producers | `app` | Deployment + HPA | Generates GPU + token usage events; scales based on CPU metrics. |
| Monitoring Stack | `monitoring` | Helm chart | kube-prometheus-stack + Grafana + Node Exporters + Alerting. |
| Logging Stack | `monitoring` | Helm chart | Loki + Promtail for distributed logs ingestion. |

---

### Processing Pipeline (Data Flow)

```

Producers → Kafka Topics (gpu.metrics.v1 / token.usage.v1)
↓
Processor (FastAPI + Consumer Loop)
↓
MongoDB (Collections: gpu_metrics, token_usage, gpus)
↓
Prometheus scrapes /metrics (Processor + Node Exporters + K8s Components)
↓
Grafana Dashboards + Alertmanager for notifications

```

---

### Key Implementation Points
- **Processor uses `starlette_exporter`** to expose native Prometheus metrics.
- **Rolling window token rate calculation** used to compute `cost_per_token` dynamically.
- **Indexes ensured at startup** to maintain query performance.
- **Producers use probabilistic workload generation** seeded from GPU profile JSON.
- **Kafka Consumer group set to `processor`** ensures at-least-once processing.
- **HPA on producers** driven by `metrics-server` availability.
- **Monitoring stack installed via** `kube-prometheus-stack` + `loki-stack`.

---

### Deployment Workflow (Make Targets Used)

| Stage | Commands | Description |
|-------|----------|-------------|
| Provision infra | `terraform apply` | Creates EC2 nodes + outputs private/public IPs. |
| Install K3s | `make bootstrap-k3s` | Installs control-plane + copies kubeconfig. |
| Add workers | `make join-workers` | Registers worker nodes via token. |
| Install monitoring prereqs | `make bootstrap-monitoring-prereqs` | Installs Helm + metrics-server. |
| Deploy monitoring stack | `make deploy-monitoring` | Installs Prometheus, Grafana, Loki, Promtail. |
| Deploy app stack | `make deploy` | Applies all manifests under `k8s/`. |
| Verify system | `make verify` | Validates Kafka, Mongo, Processor, Producers. |

---

### Observability Queries (Prometheus)

| Metric Goal | Example Query |
|------------|---------------|
| Processor request throughput | `rate(http_requests_total[5m])` |
| Kafka message lag | `kafka_consumergroup_lag` (if enabled) |
| Producer CPU scaling signal | `avg(rate(container_cpu_usage_seconds_total{pod=~"producers.*"}[2m]))` |
| Mongo write activity | `rate(mongodb_op_counters_total{type="insert"}[1m])` |
| Token usage consumption rate | `rate(processor_token_usage_tokens_total[1m])` *(custom histogram if exported)* |

---

### Current System State (at completion)
- All workloads **Running** and **Healthy**.
- **Grafana accessible** at `kubectl port-forward svc/monitoring-grafana 3000:80`.
- Producers generate live telemetry and Processor consumes and writes successfully.
- Mongo collections reflect continuous and increasing document flow.
- Metrics successfully exposed via Processor `/metrics`.
- Future optimization: Add **processor HPA** triggered by **Kafka lag** or CPU pressure.

---

### Next Recommended Enhancements
1. Configure **processor autoscaling** based on:
   - Lag-based scaling (requires `kafka_exporter`)
   - CPU-based fallback
2. Add **Grafana dashboards** that unify:
   - GPU utilization timeline
   - Token usage per model
   - Processor queue latency window
3. Enable **alerting policies** driven by:
   - Mongo insert failure rate
   - Processor error logs (via Loki label filter)
   - HPA scale-up oscillation patterns
