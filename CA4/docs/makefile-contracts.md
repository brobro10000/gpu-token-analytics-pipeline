# CA4 Makefile Contract Guide

This guide defines the **contract** for CA4 Makefile targets so that:

* Humans and agents can implement CA4 **consistently**.
* CI and graders know **what each target does**, **where it runs**, and **what it produces**.
* We preserve CA2/CA3 patterns while extending them for the new CA4 architecture.

The contract is split into:

1. **Terraform Makefile (ca4/terraform/Makefile)**
2. **Root Makefile CA4 Targets (project-level Makefile)**

---

## 1. Terraform Makefile — `ca4/terraform/Makefile`

> **Goal:** Mirror the CA3 Terraform Makefile behavior, but for CA4 infra
> (VPC, Bastion, Edge Node Group, Managed Mongo-compatible DB, S3).

### 1.1 Environment Variables

These **MUST** be supported and behave like CA3:

| Variable       | Default                                     | Purpose                                                         |
| -------------- | ------------------------------------------- | --------------------------------------------------------------- |
| `AWS_PROFILE`  | `terraform`                                 | AWS profile name to use for all CA4 Terraform commands.         |
| `AWS_REGION`   | `us-east-1`                                 | Region where CA4 VPC and resources are created.                 |
| `MY_IP_CIDR`   | auto-detected (`$(curl -s ifconfig.me)/32`) | Developer IP CIDR used to allowlist SSH / bastion / API access. |
| `SSH_KEY_NAME` | *(empty)*                                   | Optional; if set, passed into Terraform as `ssh_key_name`.      |

**Contract:** If `SSH_KEY_NAME` is set, it **must** be passed as a `-var="ssh_key_name=$(SSH_KEY_NAME)"`.
`MY_IP_CIDR` must always be passed as `-var="my_ip_cidr=$(MY_IP_CIDR)"`.

### 1.2 Required Targets

The following Make targets **MUST** exist in `ca4/terraform/Makefile`:

#### `plan`

* **Runs:** inside `ca4/terraform/`
* **Behavior:**

    * Initialize Terraform if needed: `terraform init`
    * Run `terraform plan` with:

        * `AWS_PROFILE=$(AWS_PROFILE)`
        * `-var="my_ip_cidr=$(MY_IP_CIDR)"`
        * optional `-var="ssh_key_name=$(SSH_KEY_NAME)"` if provided
    * Output plan file (e.g. `ca4.tfplan`).

#### `apply`

* **Runs:** inside `ca4/terraform/`
* **Behavior:**

    * Depends on `plan` or regenerates plan.
    * Executes `terraform apply`:

        * Using the plan file (preferred), or
        * Directly with the same vars as `plan`.
    * Creates:

        * VPC, subnets, route tables, security groups.
        * Bastion host EC2.
        * Edge node group EC2 for K3s.
        * Managed Mongo-compatible DB (DocumentDB/Atlas in VPC).
        * S3 bucket for CA4 archives.
    * Exposes outputs:

        * `ca4_vpc_id`, `ca4_subnet_ids`, `bastion_public_ip`,
        * `edge_node_private_ips`, `ca4_db_endpoint`, `ca4_s3_bucket`, etc.

#### `destroy`

* **Runs:** inside `ca4/terraform/`
* **Behavior:**

    * Destroys all CA4 infra resources.
    * Uses same env vars as `apply`.
    * Must be idempotent (safe to run multiple times).

#### `show`

* **Behavior:** `terraform show` with `AWS_PROFILE=$(AWS_PROFILE)`.

#### `state`

* **Behavior:** `terraform state list` with `AWS_PROFILE=$(AWS_PROFILE)`.

#### `clean`

* **Behavior:** Remove Terraform cache/plan files but **keep** state:
  `rm -rf .terraform *.tfplan .terraform.lock.hcl`

#### `nuke`

* **Behavior:** Remove **all** local Terraform artifacts including state files
  (`terraform.tfstate*`). This is **dangerous** and must be documented as such.

---

## 2. Root Makefile — CA4 Targets

> **Goal:** Provide a **single entry surface** for CA4 work, wrapping Terraform and K8s operations.
> Targets here should be run from the project root (same as CA2/CA3).

### 2.1 Naming & Conventions

All CA4 root-level targets use the prefix:

* `ca4-<action>`

They should:

* **CD into the right directory** (`ca4/terraform`, `ca4/k8s`, `scripts/`).
* Call underlying scripts/Makefiles as needed.
* Fail fast with clear errors if prerequisites are missing.

### 2.2 Required Root Targets

#### `ca4-plan`

* **Purpose:** Run Terraform plan for CA4.
* **Behavior:**

    * `cd ca4/terraform && make plan`
* **Inputs:** Env vars `AWS_PROFILE`, `AWS_REGION`, `MY_IP_CIDR`, `SSH_KEY_NAME`.
* **Outputs:** `ca4.tfplan` (or equivalent), printed diff.

#### `ca4-apply`

* **Purpose:** Provision CA4 AWS infra.
* **Behavior:**

    * `cd ca4/terraform && make apply`
* **Post-condition:**

    * VPC, bastion, edge nodes, DB, and S3 exist.
    * `terraform output` returns valid CA4 endpoints.

#### `ca4-destroy`

* **Purpose:** Tear down CA4 AWS infra.
* **Behavior:**

    * `cd ca4/terraform && make destroy`

#### `ca4-bootstrap-k3s`

* **Purpose:** Install K3s on edge node group and fetch kubeconfig.
* **Behavior:**

    * Uses Terraform outputs for edge node IPs + SSH key.
    * Calls a script like `scripts/bootstrap_k3s_ca4.sh`.
    * Writes kubeconfig to e.g. `./kubeconfigs/ca4-kubeconfig`.
* **Post-condition:**

    * `kubectl --kubeconfig=... get nodes` shows Ready nodes.

#### `ca4-platform-setup`

* **Purpose:** Prepare Kubernetes base platform for CA4.
* **Behavior:**

    * Use CA4 kubeconfig.
    * `kubectl apply`:

        * Namespaces: `platform`, `app`, `monitoring`.
        * Secrets/ConfigMaps:

            * DB credentials (using Terraform outputs).
            * S3 config.
            * Any shared configuration (e.g. CA4 labels/annotations).
* **Post-condition:**

    * Namespaces exist, Secrets are populated.

#### `ca4-deploy-edge`

* **Purpose:** Deploy Processor API, Kafka, Worker into K3s.
* **Behavior:**

    * `kubectl apply -f` manifests under `ca4/k8s/app/` and `ca4/k8s/platform/`:

        * `processor-api.yaml` (Deployment + Service)
        * `kafka.yaml` (StatefulSet + Service)
        * `metadata-worker.yaml` (Deployment)
    * Optionally patch with `kustomize`/Helm if used.
* **Post-condition:**

    * All three Deployments/StatefulSets are `Ready`.

#### `ca4-deploy-monitoring`

* **Purpose:** Deploy Prometheus, Loki, Grafana, Promtail for CA4.
* **Behavior:**

    * Reuse CA3 monitoring stack as much as possible.
    * `kubectl apply` or `helm upgrade --install` for:

        * Prometheus
        * Loki + Promtail
        * Grafana
* **Post-condition:**

    * Monitoring components are running and scraping/logging CA4 pods.

#### `ca4-verify-preflight`

* **Purpose:** Quick cluster sanity check.
* **Behavior:**

    * `kubectl get nodes` – ensure Ready.
    * `kubectl get pods -A` – ensure CA4-critical pods Running.
    * Exit non-zero on failure.
* **Output:** Human-readable summary of cluster health.

#### `ca4-verify-kafka`

* **Purpose:** Verify Kafka for CA4.
* **Behavior (example):**

    * Port-forward or tunnel to Kafka from dev host.
    * Use `kafkacat` / `kafka-topics.sh` to:

        * Check broker status.
        * Assert `gpu-metadata` topic exists.
* **Post-condition:**

    * Prints topic list; non-zero exit on failure.

#### `ca4-verify-db`

* **Purpose:** Verify DB connectivity from cluster.
* **Behavior:**

    * Run a `kubectl exec` into a toolbox pod or Worker.
    * Use `mongo` client or Python script to:

        * Connect to `MONGO_URI` from Secret.
        * Insert + read a test document.
* **Post-condition:**

    * Confirms DB reachable and credentials valid.

#### `ca4-verify-e2e`

* **Purpose:** Full end-to-end test.
* **Behavior:**

    * Option 1: Run a local Python client that mimics Colab, hitting Processor API ingress.
    * Option 2: Trigger a `Job` or script in-cluster that simulates a Colab POST.
    * Steps:

        * POST `/metadata` to Processor API with sample payload.
        * Validate:

            * message appears in `gpu-metadata` topic,
            * Worker consumes it (via logs or metrics),
            * Document appears in DB,
            * (Optional) artifact in S3.
* **Output:** Clear PASS/FAIL with summary.

#### `ca4-open-grafana` (Optional but Recommended)

* **Purpose:** Convenient Grafana access.
* **Behavior:**

    * Either:

        * `kubectl port-forward svc/grafana -n monitoring 3000:3000`, or
        * instruct SSH tunnel via Bastion.
* **Post-condition:**

    * Grafana accessible at `http://localhost:3000`.

#### `ca4-clean`

* **Purpose:** Clean CA4-only artifacts (plans, temp manifests), not infra.
* **Behavior:**

    * Delegates to `ca4/terraform/Makefile clean`.
    * Removes CA4 kubeconfig/temporary files if desired.

#### `ca4-nuke` (Optional, high-risk)

* **Purpose:** Remove **all** CA4 local state, including Terraform state.
* **Behavior:**

    * Delegates to `ca4/terraform/Makefile nuke`.
    * Must be clearly documented as destructive.

---

## 3. Expectations for Agents and Humans

When an agent (or human) implements CA4:

* All targets above **must** exist and behave as described.
* CA4 infra must be reproducible via:

```bash
make ca4-plan
make ca4-apply
make ca4-bootstrap-k3s
make ca4-platform-setup
make ca4-deploy-edge
make ca4-deploy-monitoring
make ca4-verify-preflight
make ca4-verify-e2e
```

* Targets should **reuse CA2/CA3 patterns** wherever possible:

    * Folder layout.
    * Terraform variable handling.
    * Kubeconfig location.
    * Monitoring install strategies.
