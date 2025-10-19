# CA2 Architecture — Terraform + K3s on AWS

**Diagram:**

* Deployment view (PlantUML, rendered): [CA2 – Terraform + K3s on AWS](https://www.plantuml.com/plantuml/svg/ZLJXRjis5_tFfxZ8dy_6DyUsqcr5VWHLb3OnKZj2bJP_30ICV6KJeaY1fEfwGuQzmzvmJpBoobRKf1c6eWd3UyxXFPVKUMSTDwwf92HnT1-RV2CSvguno9nm4iCs_FtdNt2Bnl12cmh-3zSd5hI2-2w3mGNMKkygL0w-2DmE6REbK3Ktl0AxuIkz5MeD1PSMUvLSLxLMdfIvdKGm_aYkrh8FsHfUtucLsq0qcVJsA_vjZjRoDMRYDuHfD66iuyDHlAg4We-yThe-0cuXlfZF5l0xWwT3uQXi7Zn5UYzpNc8X92xLuFhp-VlaPl5XTWbIvrmEYN_TGh_dPzaLt3PAeLogQVJhySJ_cvx-ykRD2OpE8AzfIVGMnHuPKthb-mj3-v8cLFE_gR72-q8lYdbZXDl1fT5DRGcINH82e6UH1uk-ibIXZK4K3Rs2hc2d6mEpj7KTCDdbSshvrjw7FYpHgTz1dCw6Fy5q4lqyWK4OZ4GtNAg5XwNQE3jE5ZCGog5HNBOZUMj9sfi2Q6rbpOD2rxRy-PnwFfJU9z4f95eveoMaaYiaM9BkKTyDDZoj3CrND4lb6mCQv5Bbsk1AMHX3XSw8t8uiWVo6CnmBKPAcPoVfNfGR9mgU7ovRgqAiOM2mqWwzlJ6wV6ouoZTenkM93V-FTxpo5_h7-8anmc-jSQfr3o8frdJC8tjkz4wR4WrC2NetVSrZlFPBmj1gsggz8XQrOj5_58lwhTKyB_dQ2uQsZKA75XBPM8TcVvTPAzl7BdY5rl-5fr1Bxi9dJ-15Tfz-Z6y_t7oQ4-bbDxmeEGmonnqMZSpe9LqXNqcqxSMA85e662aIuKTASwtM-kBykLOdKOKwIH1oB_7uBqvuNHzCn6dwu_vJetEqLfj-iFMFhGy0akhWhsYjcXoDxMkDhzAupPMkt6-TVZw6jFWVZ4OZ-8IIEw6LtOZQXXssZoE_Fjjd2_XvxZV35vDpAQrFiw-2jp6sqTRHPpHaBO6uzAbuQg7DbfkL1QU1KDq9nyTdXxVkSOr5orZB6lbKLwF3otsv5p7MkMiFesVXfzSyI64tx6dC_MhkVJOLFglIzVhgrWY78KKTWX7hZGDTW8-XGngUWa_35s78kiGZI30ufgZh4etTr672NBRLbasYWOvg1Kg7Wz_vPLD9zWy0)

---

## 1) Overview

CA2 deploys a GPU analytics pipeline onto a **K3s** Kubernetes cluster provisioned on **AWS EC2** by **Terraform** and operated from a local workstation with a **Makefile**. The design favors reproducibility (IaC), fast bootstrap, and simple, observable components.

**Namespaces**

* `platform`: shared infrastructure (Kafka, MongoDB)
* `app`: workloads (Processor, Producers, HPA)

**Data flow**
`Producers → Kafka → Processor → MongoDB`

### Diagram:
![PlantUML](https://www.plantuml.com/plantuml/svg/ZLJXRjis5_tFfxZ8dy_6DyUsqcr5VWHLb3OnKZj2bJP_30ICV6KJeaY1fEfwGuQzmzvmJpBoobRKf1c6eWd3UyxXFPVKUMSTDwwf92HnT1-RV2CSvguno9nm4iCs_FtdNt2Bnl12cmh-3zSd5hI2-2w3mGNMKkygL0w-2DmE6REbK3Ktl0AxuIkz5MeD1PSMUvLSLxLMdfIvdKGm_aYkrh8FsHfUtucLsq0qcVJsA_vjZjRoDMRYDuHfD66iuyDHlAg4We-yThe-0cuXlfZF5l0xWwT3uQXi7Zn5UYzpNc8X92xLuFhp-VlaPl5XTWbIvrmEYN_TGh_dPzaLt3PAeLogQVJhySJ_cvx-ykRD2OpE8AzfIVGMnHuPKthb-mj3-v8cLFE_gR72-q8lYdbZXDl1fT5DRGcINH82e6UH1uk-ibIXZK4K3Rs2hc2d6mEpj7KTCDdbSshvrjw7FYpHgTz1dCw6Fy5q4lqyWK4OZ4GtNAg5XwNQE3jE5ZCGog5HNBOZUMj9sfi2Q6rbpOD2rxRy-PnwFfJU9z4f95eveoMaaYiaM9BkKTyDDZoj3CrND4lb6mCQv5Bbsk1AMHX3XSw8t8uiWVo6CnmBKPAcPoVfNfGR9mgU7ovRgqAiOM2mqWwzlJ6wV6ouoZTenkM93V-FTxpo5_h7-8anmc-jSQfr3o8frdJC8tjkz4wR4WrC2NetVSrZlFPBmj1gsggz8XQrOj5_58lwhTKyB_dQ2uQsZKA75XBPM8TcVvTPAzl7BdY5rl-5fr1Bxi9dJ-15Tfz-Z6y_t7oQ4-bbDxmeEGmonnqMZSpe9LqXNqcqxSMA85e662aIuKTASwtM-kBykLOdKOKwIH1oB_7uBqvuNHzCn6dwu_vJetEqLfj-iFMFhGy0akhWhsYjcXoDxMkDhzAupPMkt6-TVZw6jFWVZ4OZ-8IIEw6LtOZQXXssZoE_Fjjd2_XvxZV35vDpAQrFiw-2jp6sqTRHPpHaBO6uzAbuQg7DbfkL1QU1KDq9nyTdXxVkSOr5orZB6lbKLwF3otsv5p7MkMiFesVXfzSyI64tx6dC_MhkVJOLFglIzVhgrWY78KKTWX7hZGDTW8-XGngUWa_35s78kiGZI30ufgZh4etTr672NBRLbasYWOvg1Kg7Wz_vPLD9zWy0)

---

## 2) Infrastructure (Terraform)

**Resources**

* VPC + Subnet
* Security Groups:

    * **admin SG**: SSH **22/tcp** from your public IP
    * **k8s_nodes SG**: **6443/tcp** (apiserver), **10250/tcp** (kubelet), CNI ports; intra-SG allow-all for node-to-node
* EC2:

    * Control plane (public IP)
    * Optional workers (private IPs)

**Outputs used by Makefile**

* `control_plane_public_ip`
* `worker_private_ips[]`
* `remote_kubeconfig_path` (on control plane)

---

## 3) Cluster (K3s)

* **Control plane** runs the K3s server + core addons (CoreDNS, metrics-server, Traefik).
* **Workers** run K3s agents (optional for CA2 MVP; Processor/Producers can also run on the CP).
* K3s writes `/etc/rancher/k3s/k3s.yaml`. A user-friendly copy is exported to `~/kubeconfig-external.yaml` and pulled locally.

**Access patterns**

* **Tunnel mode** (no extra SG rules):
  `ssh -N -L 6443:127.0.0.1:6443 ubuntu@<cp-ip>` and kubeconfig uses `https://127.0.0.1:6443`
* **Public-IP mode** (allow 6443 from your IP):
  kubeconfig uses `https://<cp-public-ip>:6443` with TLS SAN set during bootstrap

---

## 4) Workloads (Kubernetes)

### Platform namespace

| Component | Kind                                             | Exposure                | Notes                                                                                                    |
| --------- | ------------------------------------------------ | ----------------------- | -------------------------------------------------------------------------------------------------------- |
| Kafka     | StatefulSet (1) + **headless** Service (`kafka`) | In-cluster (9092, 9093) | Single-node KRaft; `ALLOW_PLAINTEXT=yes`; advertise pod DNS (`kafka-0.kafka.platform.svc.cluster.local`) |
| MongoDB   | StatefulSet (1) + Service (`mongo`)              | In-cluster (27017)      | For MVP, ephemeral storage OK; can switch to PVC later                                                   |

### App namespace

| Component | Kind                        | Env                                                                                                                      | Notes                                |
| --------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------ |
| Processor | Deployment                  | `KAFKA_BOOTSTRAP=kafka.platform.svc.cluster.local:9092` `MONGO_URL=mongodb://mongo.platform.svc.cluster.local:27017/ca2` | Consumes from Kafka, writes to Mongo |
| Producers | Deployment (+ optional HPA) | `KAFKA_BOOTSTRAP=...`                                                                                                    | Generates messages into Kafka topics |

---

## 5) Networking & Names

**Internal DNS (examples)**

* Kafka broker pod: `kafka-0.kafka.platform.svc.cluster.local`
* Kafka Service (headless): `kafka.platform.svc.cluster.local`
* Mongo Service: `mongo.platform.svc.cluster.local`

**Ports**

* Kafka: 9092 (client), 9093 (controller), optional 29092 (internal IB)
* Mongo: 27017
* K3s API: 6443

---

## 6) Operations (Makefile)

**Core**

* `make bootstrap-k3s` — install K3s on CP, export kubeconfig, pull locally
* `make kubeconfig` / `make kubeconfig-fix` — fetch/repair local kubeconfig
* `make tunnel` — open SSH tunnel for `127.0.0.1:6443`
* `make deploy` / `make undeploy` — apply/delete `CA2/k8s/**`
* `make status` — nodes + pods (across namespaces)

**Verification**

* `make verify-kafka` / `verify-mongo` / `verify-processor` / `verify-producers`
* `make verify-all`

**SSH convenience**

* `make ssh-control-plane`
* `make ssh-worker1` / `ssh-worker2` (via CP, with copied key or ProxyJump)

---

## 7) Debugging Cheatsheet

**Kafka not Ready**

* Ensure:

    * Headless Service `kafka` exists and selectors match `app: kafka`
    * `ALLOW_PLAINTEXT=yes`
    * `ADVERTISED_LISTENERS` uses pod DNS
    * Readiness probe uses `kafka-broker-api-versions.sh` vs `localhost:9092`

**ImagePullBackOff (Processor/Producers)**

* Validate image name/tag and registry access (`imagePullSecrets`)
* Set `imagePullPolicy: Always` during dev
* Ensure env points to in-cluster hostnames (above)

**TLS / validation errors**

* Use `make tunnel` if kubeconfig is `127.0.0.1:6443`
* Or regenerate kubeconfig with CP public IP and allow **6443** from your IP in SG

---

## 8) Security Model (minimal viable)

* No node ports exposed publicly in MVP.
* Admin access via SSH (22) and either:

    * SSH tunnel to API (preferred), or
    * Restricted 6443 from admin IP.
* Intra-cluster allow-all within `k8s_nodes` SG for CNI + control traffic.

---

## 9) Extensibility

* **Storage**: replace `emptyDir` with PVCs backed by EBS (StorageClass + `volumeClaimTemplates`).
* **Scaling**: increase StatefulSet replicas for Kafka (3) with proper quorum voters; enable HPA on Producers.
* **Ingress**: expose Processor `/health` via Traefik with Ingress resources.
* **Observability**: add Prometheus/Grafana stack or k3s built-ins.

---

## 10) Files & Locations

```
CA2/
├─ terraform/…                      # VPC, SGs, EC2, outputs
├─ Makefile                         # bootstrap, tunnel, deploy, verify
├─ k8s/
│  ├─ platform/
│  │  ├─ kafka.yaml                 # Headless SVC + StatefulSet (1)
│  │  └─ mongo.yaml                 # SVC + StatefulSet (1)
│  └─ app/
│     ├─ processor.yaml             # Deployment
│     └─ producers.yaml             # Deployment (+ HPA optional)
└─ .kube/kubeconfig.yaml            # local kubeconfig
```

---

## 11) Demo / Grading Checklist (quick view)

* **Infra up** (`terraform apply`) → control plane IP output
* **Cluster Ready** (`make status`)
* **Namespaces present** (`kubectl get ns`)
* **Kafka & Mongo Running** (`make verify-kafka`, `make verify-mongo`)
* **Processor & Producers Running** (`make verify-processor`, `make verify-producers`)
* **End-to-end logs** show ingest → process → write to Mongo
* **Automation**: `make deploy`, `make verify-all` succeed
* **Access**: either `make tunnel` or kubeconfig with public IP works