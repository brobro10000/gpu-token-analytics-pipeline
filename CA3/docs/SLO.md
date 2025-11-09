# **SLO — CA3 Streaming & API Service**

## 1) Purpose

This document defines **internal performance and reliability objectives** for the CA3 streaming pipeline and Processor API.
These targets guide operational expectations and trigger proactive remediation through alerts (burn-rate alerting model).

---

## 2) Critical User Journeys (CUJs)

| CUJ                                    | Description                                    | Component Path                        |
| -------------------------------------- | ---------------------------------------------- | ------------------------------------- |
| **CUJ-1: Retrieve latest GPU info**    | User queries `/gpu/info` via Processor         | Processor API → Mongo                 |
| **CUJ-2: Metric ingestion continuity** | Producers send GPU + token events continuously | Producers → Kafka → Processor → Mongo |

All SLOs tie directly to these two CUJs.

---

## 3) SLO Targets

### **SLO-1 — API Availability**

The Processor’s `/health` and `/gpu/info` endpoints should return **2xx responses ≥ 99.5%** monthly.

**Metric:** `http_requests_total` (provided by `starlette_exporter`)

**PromQL Calculation**

```promql
api_success_ratio =
(
  sum(rate(starlette_requests_total{job="processor",status=~"2.."}[5m]))
  /
  sum(rate(starlette_requests_total{job="processor"}[5m]))
)

api_success_ratio
```

**SLO Condition**

```
api_success_ratio >= 0.995 over 30 days
```

---

### **SLO-2 — Request Latency (p95)**

Users should see **p95 latency ≤ 200ms** measured over rolling 1 hour windows.

**PromQL**

```promql
histogram_quantile(
  0.95,
  sum(rate(starlette_request_duration_seconds_bucket{job="processor"}[5m])) by (le)
)
```

**SLO Condition**

```
p95_latency <= 0.200 seconds for >= 99% of hours
```

---

### **SLO-3 — End-to-End Message Processing Time**

Messages from Producers should be **processed and stored within ≤ 10 seconds** 99% of the time.

This SLO spans:

```
Kafka enqueue → Processor consume → Mongo write
```

**SLI Idea:** (requires small code addition — recommended but optional)

```python
ts_kafka_ingest - ts_mongo_write <= 10 seconds
```

**Approximate Lag (proxy, if Kafka Lag Exporter not yet installed)**

```promql
sum(rate(app_processed_messages_total[1m])) 
/
sum(rate(app_produced_messages_total[1m]))
```

**SLO Condition**

```
processed_rate >= produced_rate for >= 99% of minutes
```

---

### **SLO-4 — Pipeline Reliability (Restarts)**

Processor pods should restart **< 3 times per day**.

**PromQL**

```promql
increase(kube_pod_container_status_restarts_total{namespace="app",pod=~"processor-.*"}[24h])
```

**SLO Condition**

```
restarts_per_day < 3
```

---

## 4) Burn-Rate Alerting (Recommended)

| Window    | Burn Rate Threshold | Condition Trigger                |
| --------- | ------------------- | -------------------------------- |
| 5 minutes | 14.4×               | Fast detect critical outage      |
| 1 hour    | 6×                  | Sustained degradation            |
| 24 hours  | 1×                  | Near violation of monthly target |

**Example Alert (Availability Burn Rate)**

```yaml
- alert: ProcessorAvailabilityBurnRateHigh
  expr: (1 - api_success_ratio) > (1 - 0.995) * 14.4
  for: 5m
  labels: {severity: "critical"}
  annotations:
    summary: "Processor API SLO burn rate too high (5m window)"
```

---

## 5) Evaluation & Reporting

| Frequency | Report Type                     | Recipient    |
| --------- | ------------------------------- | ------------ |
| Daily     | Slack/console status            | Engineering  |
| Weekly    | Performance review & HPA tuning | Team         |
| Monthly   | SLO summary vs SLA              | Stakeholders |

---

## 6) When SLOs Are Missed

Action items are triggered **before** SLA breach:

| SLO Missed        | Remediation                                              |
| ----------------- | -------------------------------------------------------- |
| Availability      | Increase replicas or fix crash-loop root cause           |
| Latency           | Tune HPA CPU target / increase cluster capacity          |
| Processing Lag    | Scale Processor horizontally / increase Kafka partitions |
| Restart Stability | Investigate memory leaks or misconfiguration             |

---

## 7) Ownership

| Area                         | Owner               |
| ---------------------------- | ------------------- |
| Processor code & performance | Application team    |
| Kafka & Mongo stability      | Platform team       |
| Monitoring & Alerts          | Observability / SRE |

---

### ✅ Document Summary (Short)

We commit to **high availability**, **low latency**, **timely processing**, and **pipeline reliability**, using **PromQL-based measurement** and **burn-rate alerting** to enforce operational quality before SLAs are impacted.
