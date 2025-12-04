# **CA4 Architecture Overview (Updated with Kafka Connectivity & Agent Workflow)**

## **1. Purpose of CA4**

CA4 extends CA2/CA3 into a **multi-cloud GPU → Edge → Streaming → Database** pipeline that supports:

* **GPU/TPU metadata extraction in Google Colab**
* **Processor API ingestion (local or AWS)**
* **Kafka streaming inside AWS VPC**
* **Worker transformations on K3s**
* **DocumentDB + S3 durable storage**
* **Full observability (Prometheus, Loki, Grafana)**
* **Agent-driven automation using Makefile + Terraform contracts**
* **ngrok-based dev ingestion**

A new dimension in CA4 is the **agentic workflow**, enabling an autonomous agent to fully deploy, configure, observe, and validate the system.

---

# **2. CA4 in One Sentence**

> **CA4 is a distributed, agent-operable GPU ingestion pipeline where Colab sends metadata → Processor API publishes to Kafka → Workers transform → DocumentDB/S3 store results, with secure bastion connectivity and ngrok-enabled local development.**

---

# **3. High-Level System Context (C4 Level 1)**

```
Colab User (GPU/TPU)
   ↓ POST /metadata (ngrok or AWS ingress)
Processor API
   ↓ produces event
Kafka (gpu-metadata topic)
   ↓ consumes
Metadata Worker
   ↓ writes
DocumentDB + S3
   ↓ emits metrics/logs
Prometheus / Loki / Grafana
```

---

# **4. Development Ingestion Flow (ngrok Integration)**

Colab cannot call `localhost:8000`, so CA4 introduces **ngrok** for dev-mode ingestion:

1. Run FastAPI locally:

   ```bash
   uvicorn server:app --host 0.0.0.0 --port 8000
   ```

2. Expose it with ngrok:

   ```bash
   ngrok http 8000
   ```

3. Set the tunnel inside Colab:

   ```python
   EDGE_API_URL = "https://YOUR_NGROK_URL.ngrok-free.app"
   ```

4. Colab → ngrok → local API → Kafka (via SSH tunnel) works end-to-end.

This allows **full CA4 ingestion without provisioning AWS resources**.

---

# **5. Critical Architecture Detail: How Processor API Reaches Kafka**

Kafka runs **inside a private AWS VPC**.
How your Processor API reaches Kafka depends on *where the Processor API runs*.

---

## **5.1 Production Mode (Processor API running inside AWS K3s)**

**Processor API → Kafka** runs on the *same VPC network*:

```
Processor API Pod (K3s)
     ↓ VPC private network
Kafka StatefulSet (K3s)
```

### Why this works:

* Both are running inside the **same Kubernetes cluster**
* They share **VPC routing**
* Security Groups allow API → Kafka on port 9092
* No tunnels or public access
* Highly secure, zero cross-cloud networking

This is the **canonical CA4 architecture**.

---

## **5.2 Local Development Mode (Processor API running on your laptop)**

In dev, local FastAPI cannot directly access Kafka inside the AWS VPC.
To solve this, CA4 uses a **bastion-based SSH tunnel**.

```
Colab → ngrok → Local Processor API
                   ↓ (SSH Tunnel over Bastion)
                   Kafka in AWS VPC
```

### How you connect:

```bash
ssh -i key.pem \
    -L 9092:kafka-0.kafka-svc.platform.svc.cluster.local:9092 \
    ec2-user@<BASTION_PUBLIC_IP>
```

Now your **local Processor API** can connect to:

```python
KafkaProducer(bootstrap_servers=["localhost:9092"])
```

Kafka thinks your laptop is inside the VPC because the tunnel routes traffic through the bastion host.

### Summary of dev-mode networking:

| Component         | Connection               |
| ----------------- | ------------------------ |
| Colab → local API | ngrok tunnel             |
| Local API → Kafka | SSH tunnel via bastion   |
| Kafka → Worker    | Internal VPC, no tunnels |
| Worker → DB/S3    | Internal VPC             |
| Dev → Grafana/K3s | SSH tunnel via bastion   |

This gives a **true production-grade topology** even in local development.

---

# **6. Full Data Flow (C4 Level 2.5)**

### **1. GPU Processing (Colab)**

* Extract embeddings via ResNet50
* Embed GPU hardware info
* Package CA4 metadata envelope
* Send via ngrok to the local API or directly to AWS

### **2. Processor API**

* Validates + normalizes metadata
* Publishes event to **Kafka topic `gpu-metadata`**

### **3. Kafka**

* Stores event
* Decouples ingestion from processing
* Enables replay & scale-out

### **4. Worker**

* Consumes from Kafka
* Transforms metadata
* Writes results → DocumentDB
* Archives optionally → S3

### **5. Observability**

* Prometheus scrapes metrics
* Promtail ships logs → Loki
* Grafana dashboards visualize system health

### **6. Agent Workflow**

The agent can:

* Read diagrams + Makefiles
* Execute provisioning steps
* Deploy cluster + services
* Validate end-to-end operations
* Debug using logs + dashboards

---

# **7. Provisioning Workflow (For Humans + Agents)**

### Production

1. `make ca4-apply` → AWS VPC, Bastion, EC2 nodes
2. `make ca4-bootstrap-k3s` → Install K3s
3. `make ca4-platform-setup` → Secrets, namespaces
4. `make ca4-deploy-edge` → Processor API, Kafka, Worker
5. `make ca4-deploy-monitoring` → Prom/Loki/Grafana
6. `make ca4-verify-e2e` → Confirm ingestion → DB flow

### Development

* Run FastAPI locally
* Expose via ngrok
* Open SSH tunnel via bastion for Kafka
* Colab → ngrok → local API → Kafka works end-to-end
* Switch to AWS edge API when ready

---

# **8. Architectural Tradeoffs (Updated)**

### Strengths

| Advantage                         | Explanation                                                                               |
| --------------------------------- | ----------------------------------------------------------------------------------------- |
| **Agent-friendly**                | Deterministic Makefiles, provisioning sequences, and diagrams enable agent orchestration. |
| **Safe dev-mode ingestion**       | ngrok allows Colab to integrate without AWS costs.                                        |
| **Secure production mode**        | All Kafka/DB traffic stays inside AWS VPC.                                                |
| **Simple dev-to-prod transition** | Swap ngrok URL → AWS API URL; same schema.                                                |
| **Scalable**                      | Kafka + Workers enable horizontal scaling.                                                |
| **Reproducible**                  | Agent can rebuild entire system from scratch.                                             |

### Tradeoffs

| Tradeoff                       | Impact                                                  |
| ------------------------------ | ------------------------------------------------------- |
| **SSH tunnel required in dev** | Slightly complex but necessary for VPC-isolated Kafka.  |
| **Multi-cloud complexity**     | Two clouds + your laptop requires careful coordination. |
| **ngrok not for prod**         | Only used to enable convenient dev-mode ingestion.      |
| **Stateful Kafka**             | More operations overhead than stateless services.       |

---

# **9. Summary (Final Updated Version)**

**CA4 is a multi-cloud, agent-operable ingestion and streaming system where:**

* Colab performs GPU inference
* ngrok enables local development
* Bastion SSH tunnels enable local→Kafka communication
* Production runs entirely inside AWS VPC
* Kafka streams events
* Workers transform and store them in DocumentDB/S3
* The entire pipeline can be deployed and verified by an autonomous agent

This produces a real-world, production-aligned distributed architecture while still supporting lightweight development workflows.
