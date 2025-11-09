# SLA — CA3 Streaming & API Service

## 1) Scope

* **In-scope services**

    * **Processor API** (`/health`, `/gpu/info`, `/metrics`) – namespace `app`
    * **Streaming pipeline** (Producers → Kafka → Processor → Mongo) – namespaces `app`, `platform`
    * **Observability** (Prometheus, Grafana, Loki/Promtail) – `monitoring`
* **Business hours**: 24×7 (self-managed)
* **Regions**: Single cluster (k3s on EC2)

## 2) Availability Targets

* **Processor API Availability**: **≥ 99.5% monthly**
* **Pipeline Ingestion Availability** (messages accepted by Kafka): **≥ 99.5% monthly**

### Measurement (Prometheus)

**API availability (success rate)**

```promql
1 - (
  sum(rate(http_requests_total{job="processor", code!~"2.."}[5m])) 
  /
  sum(rate(http_requests_total{job="processor"}[5m]))
)
```

> Must stay ≥ 0.995 over 28–31 days.

**Deployment availability (replicas available / desired)**

```promql
avg(
  kube_deployment_status_replicas_available{namespace="app",deployment="processor"}
/
  kube_deployment_spec_replicas{namespace="app",deployment="processor"}
)
```

**Kafka accept availability (broker up)**

```promql
avg(up{job=~"kube-prometheus.*|prometheus-node-exporter"})  # platform health baseline
```

*(For Kafka specifics, add a Kafka exporter later; see “Future Improvements.”)*

## 3) Performance Targets

* **Processor API p95 latency (GET /gpu/info)**: **≤ 200 ms** over 1-hour windows.
* **Ingestion throughput**: **≥ 50 msgs/sec sustained** (combined topics).

### Measurement

**HTTP p95 latency**

```promql
histogram_quantile(
  0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket{job="processor", path="/gpu/info"}[5m]))
)
```

**Ingress message rate (Producer → Kafka)**
*(Assumes you emit counters in producers as `app_produced_messages_total`—can add fast if not present.)*

```promql
sum(rate(app_produced_messages_total[1m]))
```

**Processed message rate (Processor)**
*(Expose `app_processed_messages_total` in processor; otherwise approximate via request logs/insert counters.)*

```promql
sum(rate(app_processed_messages_total[1m]))
```

**Backlog proxy (Produced – Processed)**

```promql
clamp_min(
  sum(rate(app_produced_messages_total[5m])) 
- sum(rate(app_processed_messages_total[5m])), 0)
```

## 4) Data Durability & Integrity

* **Mongo write success rate**: **≥ 99.9%** (excluding app-level validation errors)
* **No data loss on normal pod restarts** (PersistentVolumes for Kafka/Mongo)

**Mongo write error rate (needs an app counter)**

```promql
1 - (
  sum(rate(app_mongo_write_errors_total[5m]))
  /
  sum(rate(app_mongo_writes_total[5m]))
)
```

## 5) Support & Response

* **P1 (total outage)**: Acknowledge ≤ 15 min; mitigate ≤ 1 hr.
* **P2 (degraded: p95 > 200ms or backlog growing)**: Ack ≤ 30 min; mitigate ≤ 4 hrs.
* **P3 (non-urgent)**: Next business day.

Track via Alertmanager routing + labels (`severity=critical|warning|info`).

## 6) Maintenance & Exclusions

* Planned maintenance windows announced ≥ 24 hrs in advance; excluded from SLA if outage ≤ 30 min.
* Exclusions: Cloud provider regional outage, customer network/firewall, misconfiguration outside provided manifests.

## 7) Compliance & Credits

* If **monthly API availability** < 99.5%, provide a retrospective and remediation plan (internal); optionally scale resources / tune HPA.

---

## Alert Rules (examples)

**CRITICAL — Processor down**

```yaml
- alert: ProcessorDeploymentUnavailable
  expr: (kube_deployment_status_replicas_available{namespace="app",deployment="processor"}
        < kube_deployment_spec_replicas{namespace="app",deployment="processor"})
        and on() (time() - process_start_time_seconds{job="processor"} > 300)
  for: 5m
  labels: {severity: "critical"}
  annotations:
    summary: "Processor not fully available"
```

**WARNING — API p95 latency high**

```yaml
- alert: ProcessorLatencyHighP95
  expr: histogram_quantile(
          0.95,
          sum by (le) (rate(http_request_duration_seconds_bucket{job="processor"}[5m]))
        ) > 0.2
  for: 10m
  labels: {severity: "warning"}
  annotations:
    summary: "Processor API p95 latency > 200ms"
```

**WARNING — Backlog growing (Produced > Processed)**

```yaml
- alert: PipelineBacklogGrowing
  expr: (sum(rate(app_produced_messages_total[5m]))
       - sum(rate(app_processed_messages_total[5m]))) > 10
  for: 10m
  labels: {severity: "warning"}
  annotations:
    summary: "Message backlog increasing"
```

**INFO — Kafka broker not scraped**

```yaml
- alert: KafkaExporterMissing
  expr: absent(up{job="kafka-exporter"})
  for: 15m
  labels: {severity: "info"}
  annotations:
    summary: "Kafka exporter missing (install to get lag/queue metrics)"
```

---

## Dashboards (quick pointers)

* **Processor Overview**: success rate, p50/p95 latency, RPS, replicas, CPU/Memory, HPA desired replicas.
* **Pipeline Flow**: produced vs processed rate, backlog proxy, Mongo inserts/sec, Mongo errors.
* **Infra**: node CPU, memory, disk, pod restarts.

---

## Future Improvements (non-blocking for SLA)

* Deploy **Kafka Exporter** to get true **consumer group lag**:

    * Prometheus job `kafka_broker`, metrics like `kafka_consumergroup_lag`.
* Emit a few **app counters**:

    * `app_produced_messages_total`
    * `app_processed_messages_total`
    * `app_mongo_writes_total`, `app_mongo_write_errors_total`
* Add **synthetic check** `blackbox_exporter` for `/gpu/info`.