# 🧩 CA2 — Orchestrated GPU Analytics Pipeline (Terraform + K3s)

## 📘 Summary

CA2 extends the GPU analytics pipeline onto a self-managed **Kubernetes (K3s)** cluster orchestrated with **Terraform** and **Makefile automation**.

This setup provisions a full working cluster (control plane + workers) on AWS EC2 instances, bootstraps K3s automatically, and deploys all platform services (Kafka, MongoDB) and application workloads (Processor, Producers).

It supports:

* Automatic **Kafka KRaft cluster ID generation**
* Cloud-init topic creation on Kafka startup
* Container image builds via GitHub Container Registry (GHCR)
* Full **scaling validation** (manual + autoscale)
* KUBECONFIG-based verification commands for reproducibility

---

## 🧠 High-Level Architecture

### Infrastructure (Terraform)

* **VPC**, subnets, security groups
* **EC2 instances**: control plane + workers
* **Cloud-init user data** bootstraps each node (Kafka, Mongo, Processor)
* Outputs:

    * Control-plane public IP
    * Local `.kube/kubeconfig.yaml`

### Cluster Composition

| Namespace  | Components                                  |
| ---------- | ------------------------------------------- |
| `platform` | Kafka (KRaft mode), MongoDB                 |
| `app`      | Processor, Producers, HPA for scaling tests |

---

## ⚙️ Deployment Workflow

### 1️⃣ Create the Cluster (Terraform)

```bash
cd CA2/terraform
terraform init
terraform apply
```

This will:

* Provision EC2 instances for control plane and workers
* Inject `cloud-init` user data to auto-install Docker and K3s
* Return the control plane public IP

---

### 2️⃣ Bootstrap K3s

```bash
make bootstrap-k3s
```

This installs K3s, generates a join token, and uploads your kubeconfig.

Validate with:

```bash
make status
```

---

### 3️⃣ Create Local Tunnel (Optional)

If your kubeconfig points to localhost:

```bash
make tunnel
```

---

### 4️⃣ Deploy Services

```bash
make deploy
```

This applies all manifests under `k8s/`, including:

* Kafka StatefulSet (KRaft mode, self-formatting via init container)
* MongoDB StatefulSet
* Processor Deployment
* Producers Deployment + ConfigMap + HorizontalPodAutoscaler

---

## 🧩 Key Implementation Details

### 🐝 Kafka (KRaft Mode)

* Automatically formats storage and generates `CLUSTER_ID` at boot
* Creates topics (`gpu.metrics.v1`, `token.usage.v1`) via init container
* Headless `Service` for intra-pod DNS
* Uses `bitnami/kafka:3.7` or compatible public image

### 🍃 MongoDB

* Deployed via StatefulSet (`mongo.platform.svc.cluster.local:27017`)
* Single replica for cost efficiency
* No persistent volume for MVP speed (uses `emptyDir`)

### ⚙️ Processor

* Consumes GPU metrics from Kafka → writes to MongoDB
* Health check at `/health`
* Built and published to GHCR (`ghcr.io/brobro10000/processor:ca2`)

### 📈 Producers

* Generates GPU metrics and token usage messages
* Continuous mode (loop-based shell runner)
* Configurable rate, batch size, and topics
* Scalable horizontally via HPA

---

## 🧪 Verification & Debugging

All verification commands run *inside the cluster context* with:

```bash
KUBECONFIG=$(KUBECONFIGL)
```

---

### Kafka

```bash
make verify-kafka
```

Displays StatefulSet, Pod, and Service info + logs.

### Mongo

```bash
make verify-mongo
```

Checks StatefulSet, logs, and Mongo service exposure.

### Processor

```bash
make verify-processor
```

* Confirms `/health` endpoint
* Shows deployment rollout and logs

### Producers

```bash
make verify-producers
```

* Shows replica status
* Streams last logs
* Validates running state or crash cause

---

## 📊 Scaling Validation

### ⚙️ HPA Autoscaling Test

```bash
make verify-scale-hpa
```

* Verifies metrics-server availability
* Temporarily increases `RATE` env var to trigger CPU > 50%
* Waits for autoscale up
* Restores ConfigMap env and confirms scale down
* Works with metrics-server installed on K3s

---

## 🧠 Workflow Verification (Updated)

The old SSH + Docker workflow is now **fully Kubernetes-native**.

```bash
make verify-workflow
```

This test:

1. Verifies processor `/health`
2. Confirms Kafka topics exist
3. Captures Mongo document counts before and after producers emit
4. Ensures GPU metrics and token usage docs increased
5. Performs `/gpu/info` API spot check
6. Passes end-to-end ✅

---

## 🧩 Common Debug Patterns

| Issue                 | Symptom                                    | Fix                                            |
| --------------------- | ------------------------------------------ | ---------------------------------------------- |
| Kafka not starting    | `ErrImagePull` or `format-storage` failure | Use `bitnami/kafka:3.7`, add KRaft init script |
| Mongo CrashLoop       | Missing mount                              | Ensure `emptyDir` defined                      |
| Processor unhealthy   | 404 on `/health`                           | Check environment vars                         |
| Producers CrashLoop   | Exiting immediately                        | Run as looped container (continuous mode)      |
| Autoscale not working | No metrics                                 | Enable `metrics-server` addon                  |

---

## 📁 Repo Structure

```
CA2/
├── terraform/              # Infrastructure modules
├── Makefile                # End-to-end automation
├── k8s/
│   ├── platform/
│   │   ├── kafka.yaml
│   │   ├── mongo.yaml
│   ├── app/
│   │   ├── processor.yaml
│   │   ├── producers.yaml
│   │   ├── producers-runner.yaml
│   │   ├── hpa.yaml
├── .kube/kubeconfig.yaml   # Generated K3s config
└── README.md               # You’re here
```

---

## ✅ Demo / Grading Checklist

| Category          | Deliverable                              | Validation                                           |
| ----------------- | ---------------------------------------- | ---------------------------------------------------- |
| Terraform         | EC2 infra with public control plane      | `terraform apply`                                    |
| K3s Bootstrap     | Cluster `Ready` with kubeconfig          | `make bootstrap-k3s` + `make status`                 |
| Platform Services | Kafka + Mongo running                    | `make verify-kafka` / `make verify-mongo`            |
| App Services      | Processor + Producers deployed           | `make verify-processor` / `make verify-producers`    |
| End-to-End        | Messages flow → Processor → Mongo        | `make verify-workflow`                               |
| Scaling           | Manual + HPA autoscaling verified        | `make verify-scale-manual` / `make verify-scale-hpa` |
| Docs              | Updated README with automation + scaling | ✅ This document                                      |
