# Conversation Summary — CA2

## Timeline of Milestones

| Date (UTC) | Milestone / Topic                   | Key Decisions & Outcomes                                                                                                                                                                                                                                                          |
| ---------- | ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2025-10-18 | **CA2 handoff initialization**      | Began migration from CA1’s VM-based Docker stack to CA2’s Terraform-provisioned **K3s cluster on AWS**. Defined modules for VPC, security groups, control plane, and workers. Added Terraform output helpers and Makefile commands (`make kubeconfig`, `make ssh-control-plane`). |
| 2025-10-18 | **Cloud-init auto-install setup**   | Control plane template intended to auto-install K3s and generate `/home/ubuntu/kubeconfig-external.yaml`. Worker templates join via private IP and shared token. Encountered missing kubeconfig due to mis-templating in cloud-init.                                              |
| 2025-10-19 | **Manual bootstrap introduced**     | Created `make bootstrap-k3s` to install K3s manually via SSH, rewrite kubeconfig with public IP, and pull it locally. Verified successful `kubectl get nodes` output after bootstrap.                                                                                             |
| 2025-10-19 | **SSH topology improvements**       | Updated Makefile to support `ProxyJump` and automatic key propagation to control plane for worker SSH access. Added helper logic to copy SSH key automatically and open tunnels with `make tunnel`.                                                                               |
| 2025-10-19 | **Cluster verification**            | Confirmed K3s cluster functional using `make status`. `kubectl get nodes` returned ready control plane and workers once tunnel active. Local access achieved through `KUBECONFIG=CA2/.kube/kubeconfig.yaml`.                                                                      |
| 2025-10-19 | **Kubernetes manifests created**    | Defined `k8s/platform/kafka.yaml` and `k8s/platform/mongo.yaml` as StatefulSets with `emptyDir` storage. Both deployed under namespace `platform`. Initial deployment produced `spec.selector` mismatch; corrected by aligning labels between selectors and templates.            |
| 2025-10-19 | **Deployment + TLS debugging**      | Added `--validate=false` to Makefile `deploy` to bypass TLS validation errors while tunneling (`x509: certificate signed by unknown authority`). Confirmed working deployment via SSH tunnel (`make tunnel` active).                                                              |
| 2025-10-19 | **Kafka + Mongo running**           | Observed `mongo` running (`1/1` Ready) and `kafka` initializing (`0/1` Ready) via `make status`. Began adding targeted verify commands for each service to inspect logs and health.                                                                                               |
| 2025-10-19 | **PlantUML architecture completed** | Authored and rendered `ca2-architecture.puml` showing Terraform + K3s topology with platform/app namespaces, VPC structure, and service data flow. Linked rendered image in new `architecture.md`.                                                                                |
| 2025-10-19 | **Documentation expansion**         | Drafted new `README.md` and `architecture.md` detailing full cluster layout, Makefile operations, and service validation flow. Planned future `conversation-summary.md` for CA2 session tracking.                                                                                 |

---

## Decisions

* **Terraform Modules**

    * Reused CA1 modular pattern: VPC, SGs, Cluster.
    * Added `random_password.k3s_token` for secure node join.
    * Control plane public IP used only for admin access and kubeconfig rewriting.

* **Makefile Core**

    * Unified workflow: `make deploy`, `make undeploy`, `make status`, `make tunnel`, `make verify-*`.
    * `make bootstrap-k3s` installs K3s, exports kubeconfig, rewrites API endpoint, and pulls locally.
    * Tunnel ensures local port `127.0.0.1:6443` securely proxies control plane API.

* **Kubernetes Architecture**

    * Namespaces:

        * `platform`: Kafka (StatefulSet), MongoDB (StatefulSet)
        * `app`: Processor (Deployment), Producers (Deployment + optional HPA)
    * Services: `kafka.platform.svc.cluster.local`, `mongo.platform.svc.cluster.local`
    * Data flow: `Producers → Kafka → Processor → Mongo`

* **Security Groups**

    * Admin SG — SSH (22) from current IP.
    * K8s Nodes SG — internal 6443, 10250, and NodePorts within VPC CIDR.
    * Optional: allow 6443 from admin IP for direct kubeconfig access.

---

## Tradeoffs

* **Cloud-init Automation vs Manual Bootstrap**

    * Initial cloud-init auto-install failed silently → replaced with Makefile-driven bootstrap (`make bootstrap-k3s`) for deterministic setup.
    * Future improvement: restore automatic bootstrapping with refined templates and verified token passing.

* **Public API vs Tunnel**

    * Public access simplifies tooling but requires SG changes.
    * SSH tunnel preferred for security and portability.

* **Persistent vs Ephemeral Storage**

    * Used `emptyDir` for Kafka and Mongo MVP to accelerate iteration.
    * Future enhancement: attach EBS-backed PVCs via `volumeClaimTemplates`.

---

## Highlights

* **Fully Terraform-provisioned cluster** — reproducible with no manual EC2 steps.
* **Makefile orchestration** — automates K3s bootstrap, kubeconfig retrieval, tunnel, deploy, and verify.
* **Working K3s cluster** — verified via `kubectl get nodes` and `kubectl get pods -A`.
* **Functional Mongo** — first workload to reach `1/1 Ready`.
* **Validated PlantUML architecture** — clearly depicts Terraform, EC2 topology, and in-cluster relationships.
* **Documentation parity** — matches CA1 style with `README.md`, `architecture.md`, and conversation summary.

---

## Next Steps

* Add Makefile `verify-*` targets for:

    * `verify-kafka` → check broker logs, readiness probe, and advertised listeners.
    * `verify-mongo` → confirm database health and logs.
    * `verify-processor` → curl `/health`.
    * `verify-producers` → inspect logs or job completions.
* Extend to **app namespace deployments** (Processor + Producers YAMLs).
* Integrate persistent volumes for Mongo/Kafka.
* Implement `verify-all` aggregate target for grading.
* Add CI hooks for `terraform validate` and `kubectl apply --dry-run=server`.

---

✅ **Status:**
**CA2 cluster successfully deployed and operational on K3s.**
Kubeconfig validated via tunnel, Mongo running, Kafka initializing, and documentation complete.
Next focus: deploy application workloads and verify end-to-end data flow.
