# Conversation Summary — CA1

## Timeline of Milestones

| Date (UTC)     | Milestone / Topic                         | Key Decisions & Outcomes                                                                                                                                                                                                           |
| -------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2025-09-20     | CA1 high-level summary                    | Defined CA1 as the Infrastructure-as-Code successor to CA0. Goal: move from manual VM provisioning to automated reproducible Terraform-managed infrastructure.                                                                     |
| 2025-09-21     | Initial CA1 PUML generation               | Generated draft versions of `ca1-architecture.puml`, `ca1-provisioning-sequence.puml`, and `ca1-readme.md`. These captured a Terraform-driven design with modules for VPC, SGs, and EC2 instances, plus bootstrap with cloud-init. |
| 2025-09-21     | Updating PUML with tech details           | Integrated CA0 docs into CA1 diagrams. Annotated each VM stack: Kafka 3.7.0 (KRaft), MongoDB 7.0, FastAPI/Uvicorn processor, Python confluent-kafka producers. Added Docker Compose bootstrap.                                     |
| 2025-09-21     | Syntax correction in PUML                 | Fixed PlantUML issues: explicit aliases for SGs and modules, corrected stereotypes, fixed diagram references.                                                                                                                      |
| 2025-09-21     | Step-by-step guide                        | Authored `CA1-step-by-step-guide.md` covering repo layout, Terraform modules, VPC/SG configs, EC2 templates, cloud-init YAML, Makefile helpers, and verification steps.                                                            |
| 2025-09-21     | AWS IAM/Terraform setup                   | Clarified root is not allowed. Documented IAM user/SSO setup, permissions, CLI config, and STS validation.                                                                                                                         |
| 2025-09-21     | Running Terraform                         | Confirmed Terraform must be run from `ca1/terraform`. Listed core commands: `init`, `plan`, `apply`.                                                                                                                               |
| 2025-09-21     | Terraform state management                | `.tfstate` excluded from Git. Suggested S3 + DynamoDB backend for collaboration.                                                                                                                                                   |
| 2025-09-21     | AMI lookup fix                            | Replaced brittle `aws_ami` filter with AWS SSM parameter for Ubuntu 24.04 LTS (amd64). Eliminated lookup errors.                                                                                                                   |
| 2025-09-21     | Instance type alignment                   | Chose minimum x86 types: Kafka/Mongo → `t3.small`, Processor/Producers → `t3.micro`. Avoided ARM (`t4g.*`).                                                                                                                        |
| 2025-09-21     | Terraform variable cleanup                | Fixed single-line variable errors; switched to multi-line blocks. Added float variable `price_per_hour_usd`.                                                                                                                       |
| 2025-09-21     | Wiring module inputs                      | Passed `subnet_id` and `sg_ids` outputs from VPC/SG modules into `instances` module.                                                                                                                                               |
| 2025-09-21     | Private IP handling                       | Selected dynamic AWS-assigned private IPs. Terraform injects discovered IPs into dependent VMs (Processor/Producers).                                                                                                              |
| 2025-09-21     | Makefile improvements                     | Added `deploy` (init+plan+apply) and `down` (destroy). Split `clean` vs `nuke`. Auto-injected `my_ip_cidr`. Centralized workflow.                                                                                                  |
| 2025-09-21     | Tooling & linting                         | Integrated `terraform fmt`, `validate`, `tflint` (v0.54+ `call_module_type`), and recommended `checkov`/`tfsec`. Added pre-commit hooks.                                                                                           |
| 2025-09-21     | Outputs & data sources                    | Added root outputs: account\_id, arn, region, vpc\_id, subnet\_id, sg\_ids, instance\_private\_ips, instance\_public\_ips.                                                                                                         |
| **2025-09-21** | **Kafka VM cloud-init template creation** | Drafted `vm1-kafka.cloudinit` with Docker + Compose install, `.env` file for `KAFKA_BIND_ADDR`, and Compose spec for Bitnami Kafka 3.7 in KRaft mode. Added idempotent topic creation.                                             |
| **2025-09-21** | **Systemd Option 2 refresh unit**         | Implemented `kafka-env-refresh.service` + `/usr/local/bin/kafka-env-refresh.sh` to auto-populate `KAFKA_BIND_ADDR` via IMDS on every reboot and re-run `docker compose up -d`. Ensures resilience after stop/start.                |
| **2025-09-21** | **Terraform templatefile fixes**          | Hit `Extra characters after interpolation expression` error on `${KAFKA_BIND_ADDR:?missing}`. Solution: escape with `$${KAFKA_BIND_ADDR:?missing}` so Compose expands it, not Terraform.                                           |
| **2025-09-21** | **Debugging container health**            | Kafka container stuck in `unhealthy` state. Logs revealed `mkdir: cannot create directory '/bitnami/kafka/config': Permission denied`. Root cause: bind-mounted `/opt/kafka/data` not writable by container UID 1001.              |
| **2025-09-21** | **Permissions fix for Kafka data**        | Added `chown -R 1001:1001 /opt/kafka/data` to ensure Bitnami Kafka (non-root UID 1001) can create subdirs. Updated refresh script to enforce permissions each boot.                                                                |
| **2025-09-21** | **Mongo VM cloud-init template creation** | Drafted `vm2-mongo.cloudinit` with Docker + Compose install, named volume (`mongo_data`), init scripts (`indexes.js` and `seed-gpus.js`), and systemd refresh service. Healthcheck added with `start_period` for reliability.      |
| **2025-09-21** | **Mongo seed + verify flow**              | Added GPU seed docs (RTX 3090, A100 40GB) via `seed-gpus.js`. Extended Makefile `verify-mongo` target to check container health, databases, seed docs, and indexes for grading robustness.                                         |
| **2025-09-21** | **Processor VM cloud-init template**      | Created a cloud-init spec that installs Docker + Compose, writes `.env` with runtime values, and defines `docker-compose.yml` for the processor. Added systemd refresh service to rebuild image on each reboot.                    |
| **2025-09-21** | **Build-from-Git method**                 | Instead of embedding a zip, chose to build directly from GitHub (`gpu-token-analytics-pipeline.git#main:CA0/vm3-processor`). This ensures the latest code is pulled on every provision.                                            |
| **2025-09-21** | **Processor image details**               | Dockerfile based on `python:3.12-slim`. Includes FastAPI 0.112, Uvicorn 0.30, confluent-kafka 2.5, pymongo 4.8. Runs as non-root UID 10001. Healthcheck probes `/health`.                                                          |
| **2025-09-21** | **Service behavior**                      | Processor consumes from Kafka topics `gpu.metrics.v1` and `token.usage.v1`. Writes to MongoDB collections `gpu_metrics` and `token_usage`. Adds sliding-window throughput and computes `cost_per_token`.                           |
| **2025-09-21** | **API endpoints**                         | Provides `/health` for readiness and `/gpu/info` returning the latest GPU metrics doc.                                                                                                                                             |
| **2025-09-21** | **Makefile improvements (exec)**          | Added extensible `exec-vmX` helpers to run arbitrary commands inside containers (auto-resolves container IDs). Created `verify-processor` expanded checks: health, env, reachability to Kafka/Mongo, `/gpu/info` test, logs.       |
| **2025-09-21** | **Debugging processor health**            | Found processor container marked `unhealthy`. Root cause: slim base image lacked `curl`. Fix: either add `curl` in Dockerfile or replace healthcheck with `wget`/Python-based probe.                                               |
| **2025-09-21** | **Container naming**                      | Initially failed because container was named `processor-processor-1`. Fixed by either pinning `container_name: processor` in Compose or using `docker compose ps -q processor` in Make targets.                                    |

---

## Decisions

* **CA1 mirrors CA0**: Same 4-VM pipeline, now fully Terraform-managed.
* **VM stacks**:

    * VM1: Kafka 3.7.0 (KRaft, Bitnami container)
    * VM2: MongoDB 7.0.x
    * VM3: FastAPI 0.112 + Uvicorn 0.30 + confluent-kafka 2.5 + pymongo 4.8
    * VM4: Python 3.12 + confluent-kafka 2.5
* **Processor design**:

    * Build-from-Git ensures latest source at provision time (`CA0/vm3-processor`).
    * Environment variables passed via `.env` (`KAFKA_BOOTSTRAP`, `MONGO_URL`, `PRICE_PER_HOUR_USD`).
    * Systemd refresh script rebuilds/re-ups Compose service after reboot.
    * Provides REST API endpoints: `/health`, `/gpu/info`.
    * Inserts into Mongo collections and computes cost-per-token metrics over sliding window.

---

## Tradeoffs

* **Bind mounts vs named volumes**:

    * Kafka used bind mounts (needed permission fix).
    * Mongo switched to named volumes for simplicity.
* **Init scripts**:

    * Kept `indexes.js` and `seed-gpus.js` separate for clarity.
* **Processor build strategy**:

    * Build-from-Git avoids user-data size limits but requires network and adds build time.
* **Healthcheck choice**:

    * Slim image lacks `curl`, so better to use `wget` or Python to check `/health`.
* **Container naming**:

    * Explicit name (`container_name: processor`) simplifies verification, but dynamic ID resolution is more flexible.

---

## Highlights

* Kafka + Mongo provision cleanly, restart safely, and include healthchecks for grading.
* Processor VM auto-builds from GitHub, exposes FastAPI endpoints, and integrates Kafka + Mongo.
* Makefile now includes powerful verify flows and generic `exec-vmX` helpers.
* Debugging flows captured: Kafka permissions issue, Mongo reachability, Processor healthcheck quirks.

---

## Next Steps

* Extend templates for VM4 (Producers).
* Add `verify-producers` and `verify-all` Make targets.
* Document successful healthcheck + API outputs for Processor in CA1 README.
* Note common pitfalls (Terraform `$${}` escaping, Bitnami UID fix, slim-image healthcheck tooling).

---

✅ **Status:** Kafka, Mongo, and Processor VM templates + Make targets are complete and reproducible. Verification flows are robust, with clear debugging paths. CA1 infrastructure is nearly end-to-end; only Producers remain.
