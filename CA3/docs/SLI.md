# **Service Level Indicators (SLIs)**

These SLIs measure the reliability and performance of the CA3 data pipeline:

| Domain | SLI | Description | Metric Source | PromQL / LogQL Example |
| ------ | --- | ----------- | ------------- | ---------------------- |

## **1) Processor API Health**

**Indicator:** Ratio of successful HTTP requests to all requests
**Meaning:** Measures **application upness & correctness** at the FastAPI layer.

```promql
sum(rate(http_requests_total{job="processor",status=~"2.."}[5m]))
/
sum(rate(http_requests_total{job="processor"}[5m]))
```

**Alternative (Pod ready state):**

```promql
avg_over_time(up{job="processor"}[5m])
```

---

## **2) API Latency**

**Indicator:** P95 request duration
**Meaning:** Measures **responsiveness** under load.

```promql
histogram_quantile(
  0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket{job="processor"}[5m]))
)
```

**P99:** replace `0.95` with `0.99`.

---

## **3) Data Freshness (Ingest → Store Delay)**

**Indicator:** P95 end-to-end time from message creation to Mongo write
**Meaning:** How “fresh” the data in Mongo is relative to real-world time.

Assumes Processor emits histogram bucket:
`event_store_delay_seconds_bucket`

```promql
histogram_quantile(
  0.95,
  sum by (le) (rate(event_store_delay_seconds_bucket[5m]))
)
```

---

## **4) Kafka Consumer Lag (Processor)**

**Indicator:** Total unprocessed messages in the processor consumption group
**Meaning:** Measures pipeline backlog growth.

Requires **kafka_exporter**:

```promql
sum(kafka_consumergroup_lag{consumergroup="processor"})
```

If exporter not installed → expose & scrape this from Processor:

```promql
avg_over_time(processor_consumer_lag[5m])
```

---

## **5) Mongo Write Reliability**

**Indicator:** Error ratio of writes from Processor to MongoDB
**Meaning:** Measures data write integrity + stability.

Requires counters:
`processor_mongo_write_total{result="ok|error"}`

```promql
sum(rate(processor_mongo_write_total{result="error"}[5m]))
/
sum(rate(processor_mongo_write_total[5m]))
```

---

## **6) Producer Throughput**

**Indicator:** Events ingested per second
**Meaning:** Measures data arrival volume.

If metric exists:

```promql
sum(rate(producer_records_sent_total[5m]))
```

If not, derive via Kafka topic write rate:

```promql
sum(rate(kafka_topic_partition_current_offset{topic=~"gpu.metrics.v1|token.usage.v1"}[5m]))
```

---

## **7) Pod Availability (Kubernetes)**

**Indicator:** Available replicas vs desired
**Meaning:** Capacity + scheduling health.

```promql
sum(kube_deployment_status_replicas_available{deployment="processor",namespace="app"})
/
sum(kube_deployment_spec_replicas{deployment="processor",namespace="app"})
```

---

## **8) Resource Saturation (HPA Signals)**

### CPU

```promql
100 *
sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{namespace="app", pod=~"processor-.*"})
/
sum(kube_pod_container_resource_requests{namespace="app", resource="cpu", pod=~"processor-.*"})
```

### Memory

```promql
100 *
sum(container_memory_working_set_bytes{namespace="app", pod=~"processor-.*"})
/
sum(kube_pod_container_resource_requests{namespace="app", resource="memory", pod=~"processor-.*"})
```

---

## **9) Log Error Rate**

**Indicator:** Rate of error-level log messages
**Source:** Loki (Promtail → Loki → Grafana)

```logql
sum(rate({namespace="app", app="processor"} |= "ERROR" [5m]))
```

---

### ✅ This SLI sheet now directly supports:

* Your **SLO** burn-rate alerts
* Grafana dashboard panels
* Prometheus alert rules
