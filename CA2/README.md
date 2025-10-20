# 🧩 CA2 — Orchestrated GPU Analytics Pipeline (Terraform + K3s)

## 📘 Summary

CA2 extends the GPU analytics pipeline onto a self-managed **Kubernetes (K3s)** cluster orchestrated with **Terraform** and **Makefile automation**.

This setup provisions a full working cluster (control plane + workers) on AWS EC2 instances, bootstraps K3s automatically via cloud-init, and deploys all platform services (Kafka, MongoDB) and application workloads (Processor, Producers).

Also see the CA2 section in the repository root README for a cohesive overview and quickstart: ../README.md

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

### 1️⃣ Provision infrastructure (Terraform Makefile)

```bash
cd CA2/terraform
make deploy        # init + plan (auto-detects my_ip_cidr) + apply
make outputs       # show VPC/SG/instance outputs
```

Notes:

- Override AWS profile/region as needed: `AWS_PROFILE=terraform AWS_REGION=us-east-1 make deploy`
- Provide an explicit EC2 keypair name if not set in tfvars: `SSH_KEY_NAME=my-key make deploy`
- Security groups allow:
  - 22/tcp from my_ip_cidr (admin)
  - 6443/tcp (kube-apiserver) from my_ip_cidr
  - NodePorts (30000–32767) within the VPC (tunable)

---

### 2️⃣ Fetch kubeconfig (cluster auto-bootstrapped)

K3s is installed on the control-plane via cloud-init. Pull the kubeconfig locally and verify access:

```bash
cd CA2
make tunnel
make bootstrap-k3s
make status
```

If your kubeconfig uses 127.0.0.1:6443, use a temporary tunnel (see next step) while running kubectl.

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

### 🧩 Verify components

```bash
make verify            # runs verify-kafka, verify-mongo, verify-processor, verify-producers
make verify-workflow   # optional end-to-end baseline→nudge→delta checks
```

Or individually:

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
├── README.md
├── docs/
│   ├── architecture.md
│   └── conversation-summary.md
├── diagrams/
├── screenshots/
├── Makefile                  # SSH + deploy automation + kubeconfig + verify
├── k8s/
│   ├── platform/
│   │   ├── kafka/
│   │   │   ├── statefulset.yaml
│   │   │   └── svc.yaml
│   │   └── mongo/
│   │       ├── statefulset.yaml
│   │       └── svc.yaml
│   └── app/
│       ├── processor/
│       │   └── deploy.yaml
│       └── producers/
│           ├── deploy.yaml
│           ├── hpa.yaml
│           └── config.yaml
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

| Category                          | Deliverable                                             | Validation                                        |
| --------------------------------- | ------------------------------------------------------- | ------------------------------------------------- |
| **1. Infrastructure (Terraform)** | AWS EC2 cluster provisioned with public control plane   | `make deploy` + outputs show control plane IP     |
| **2. Cluster Setup (K3s)**        | K3s installed via cloud-init; kubeconfig pulled locally | `make kubeconfig` + `make status` shows `Ready`   |
| **3. Namespaces**                 | `app`, `platform` created                               | `kubectl get ns`                                  |
| **4. Platform Layer**             | Kafka + Mongo deployed via StatefulSets                 | `make verify-kafka`, `make verify-mongo`          |
| **5. App Layer**                  | Processor + Producers deployed via Deployments          | `make verify-processor`, `make verify-producers`  |
| **6. Connectivity**               | Processor connects to Kafka + Mongo                     | `kubectl logs -n app -l app=processor`            |
| **7. Observability**              | Pods all `Running` + `1/1 Ready`                        | `make status`                                     |
| **8. Automation**                 | Makefile executes full workflow end-to-end              | `make deploy`, `make verify`, `make verify-workflow` |
| **9. Debug**                      | Demonstrate tunnel-based kubeconfig or public-IP access | `make tunnel` + `make status`                     |
| **10. Documentation**             | Clear README with setup + results                       | ✅ This file                                       |

---

## 📎 Related Docs

* [architecture.md](./docs/architecture.md) — Updated CA2 cluster and namespace diagram
* [conversation-summary.md](./docs/conversation-summary.md) — Terraform + Makefile evolution


---

## 📸 Screenshots (by command order)

- Terraform deploy (part 1)
  
  ![make tf deploy 1](screenshots/make_tf_deploy_1.png)

- Terraform deploy (part 2)
  
  ![make tf deploy 2](screenshots/make_tf_deploy_2.png)

- Open tunnel to API server
  
  ![make tunnel](screenshots/make_tunnel_3.png)

- Bootstrap K3s and export kubeconfig
  
  ![make bootstrap-k3s](screenshots/make_bootstrap-k3s_4.png)

- Cluster status (nodes/pods)
  
  ![make status 1](screenshots/make_status_5.png)

- Apply Kubernetes manifests
  
  ![make deploy (k8s)](screenshots/make_kube_deploy_6.png)

- Cluster status after deploy
  
  ![make status 2](screenshots/make_status_7.png)

- Verify Kafka
  
  ![make verify-kafka](screenshots/make_verify-kafka_8.png)

- Verify MongoDB
  
  ![make verify-mongo](screenshots/make_verify-mongo_9.png)

- Verify Producers
  
  ![make verify-producers](screenshots/make_verify-producers_10.png)

- Verify Processor
  
  ![make verify-processor](screenshots/make_verify-processor_11.png)

- Verify end-to-end workflow
  
  ![make verify-workflow](screenshots/make_verify-workflow_12.png)

- Verify HPA scale (optional)
  
  ![make verify-scale-hpa](screenshots/make_verify-scale-hpa_13.png)

- Undeploy Kubernetes manifests
  
  ![make undeploy (k8s)](screenshots/make_kube_undeploy_14.png)

- Terraform destroy
  
  ![make down](screenshots/make_tf_down_15.png)
