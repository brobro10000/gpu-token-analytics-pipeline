# 🧩 CA2 — Orchestrated GPU Analytics Pipeline (Terraform + K3s)

## 📘 Summary

CA2 extends the GPU analytics pipeline onto a self-managed **Kubernetes (K3s)** cluster orchestrated with **Terraform** and **Makefile automation**.

This setup provisions a full working cluster (control plane + workers) on AWS EC2 instances, bootstraps K3s automatically, and deploys all platform services (Kafka, MongoDB) and application workloads (Processor, Producers).

---

## 🧠 High-Level Architecture

* **Terraform** provisions:

    * VPC, subnets, and EC2 instances
    * Security groups for admin SSH + K3s communication
    * Control-plane public IP
* **Makefile** automates:

    * SSH access, tunnel creation, and K3s bootstrapping
    * Cluster introspection (`make status`, `make logs`)
    * Kubernetes manifest deployment (`make deploy`)
    * Service-level verification (`make verify-*`)
* **K3s** hosts:

    * `platform` namespace → Kafka, MongoDB
    * `app` namespace → Processor, Producers
* **Processor** consumes GPU metrics from Kafka → stores in MongoDB
* **Producers** generate data and publish to Kafka topics

---

## 🏗️ Replication Steps

### 1️⃣ Create the Cluster via Terraform

```bash
cd CA2/terraform
terraform init
terraform apply
```

This will:

* Create EC2 control-plane and worker nodes
* Open ports for SSH and K3s API
* Output the control-plane public IP

---

### 2️⃣ Bootstrap K3s

```bash
# from /CA2
make bootstrap-k3s
```

This installs K3s on the control plane, generates and uploads the kubeconfig, and prepares the worker join token.

Validate:

```bash
make tunnel

make status
```

---

### 3️⃣ Tunnel for Local kubectl

If your kubeconfig points to `127.0.0.1:6443`, open a port-forward tunnel:

```bash
make tunnel
```

Then in another terminal:

```bash
make status
```

---

### 4️⃣ Deploy All Kubernetes Resources

```bash
make deploy
```

This applies everything under `CA2/k8s/` including:

* Namespaces (`app`, `platform`)
* StatefulSets for Kafka and MongoDB
* Deployments for Processor and Producers
* ConfigMaps/Secrets if present

---

## 🔍 Verification & Debugging

### 🌐 Check overall status

```bash
make status
```

### 🧩 Verify all components

```bash
make verify-all
```

or individually:

```bash
make verify-kafka
make verify-mongo
make verify-processor
make verify-producers
```

Each verify command:

* Shows pod + service info
* Tails logs
* Confirms resource readiness

### 🪵 Logs

```bash
make K ARGS="-n platform logs -l app=kafka --tail=100"
make K ARGS="-n app logs -l app=processor --tail=100"
```

---

## ⚙️ Common Issues

| Component            | Symptom            | Likely Fix                                                                                        |
| -------------------- | ------------------ | ------------------------------------------------------------------------------------------------- |
| **Kafka**            | `0/1` Ready        | Add `ALLOW_PLAINTEXT=yes`; ensure `ADVERTISED_LISTENERS` match pod DNS; headless `Service` exists |
| **Processor**        | `ImagePullBackOff` | Verify image path + `imagePullSecrets`; check `KAFKA_BOOTSTRAP` and `MONGO_URL`                   |
| **Producers**        | `ImagePullBackOff` | Same as processor; ensure Kafka hostname resolves                                                 |
| **Mongo**            | CrashLoopBackOff   | Ensure volume mount works; check logs                                                             |
| **kubectl validate** | TLS error          | Run `make tunnel` or regenerate kubeconfig with public IP                                         |

---

## 🧪 Manual Debug Commands

```bash
# Nodes
KUBECONFIG=.kube/kubeconfig.yaml kubectl get nodes -o wide

# Watch rollout
make K ARGS="-n app rollout status deploy/processor -w"

# Inspect services
make K ARGS="-n platform get svc -o wide"
```

---

## 📊 Validation Checks

| Step                 | Command                                | Expected Result         |
| -------------------- | -------------------------------------- | ----------------------- |
| Cluster up           | `make status`                          | Control plane Ready     |
| Kafka ready          | `make verify-kafka`                    | 1/1 Running             |
| Mongo ready          | `make verify-mongo`                    | 1/1 Running             |
| Processor running    | `make verify-processor`                | Consumes messages       |
| Producers running    | `make verify-producers`                | Publishes to Kafka      |
| End-to-end data flow | `kubectl logs -n app -l app=processor` | Shows processed records |

---

## 📁 Repo Structure

```
CA2/
├── main.tf                   # Terraform entrypoint
├── modules/
│   ├── network/              # VPC, subnets, SGs
│   ├── cluster/              # EC2 + K3s setup
├── Makefile                  # SSH + deploy automation
├── k8s/
│   ├── app/
│   │   ├── processor.yaml
│   │   ├── producers.yaml
│   ├── platform/
│   │   ├── kafka.yaml
│   │   ├── mongo.yaml
│   ├── namespaces.yaml
└── .kube/
    ├── kubeconfig.yaml
```

---

## 🎓 Grading / Demo Checklist

| Category                          | Deliverable                                             | Validation                                        |
| --------------------------------- | ------------------------------------------------------- | ------------------------------------------------- |
| **1. Infrastructure (Terraform)** | AWS EC2 cluster provisioned with public control plane   | `terraform apply` + output shows control plane IP |
| **2. Cluster Setup (K3s)**        | K3s installed + kubeconfig exported                     | `make bootstrap` + `make status` shows `Ready`    |
| **3. Namespaces**                 | `app`, `platform` created                               | `kubectl get ns`                                  |
| **4. Platform Layer**             | Kafka + Mongo deployed via StatefulSets                 | `make verify-kafka`, `make verify-mongo`          |
| **5. App Layer**                  | Processor + Producers deployed via Deployments          | `make verify-processor`, `make verify-producers`  |
| **6. Connectivity**               | Processor connects to Kafka + Mongo                     | `kubectl logs -n app -l app=processor`            |
| **7. Observability**              | Pods all `Running` + `1/1 Ready`                        | `make status`                                     |
| **8. Automation**                 | Makefile executes full workflow end-to-end              | `make deploy`, `make verify-all`                  |
| **9. Debug**                      | Demonstrate tunnel-based kubeconfig or public-IP access | `make tunnel` + `make status`                     |
| **10. Documentation**             | Clear README with setup + results                       | ✅ This file                                       |

---

## 📎 Related Docs

* [architecture.md](./architecture.md) — Updated CA2 cluster and namespace diagram
* [conversation-summary.md](./conversation-summary.md) — Terraform + Makefile evolution
