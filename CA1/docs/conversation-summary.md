# Conversation Summary — CA1

## Timeline of Milestones

| Date (UTC)     | Milestone / Topic                         | Key Decisions & Outcomes                                                                                                                                                                                                           |
|----------------| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
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

---

## Decisions

* **CA1 mirrors CA0**: Same 4-VM pipeline, now fully Terraform-managed.
* **VM stacks**:

    * VM1: Kafka 3.7.0 (KRaft, Bitnami container)
    * VM2: MongoDB 7.0.x
    * VM3: FastAPI 0.112 + Uvicorn 0.30
    * VM4: Python 3.12 + confluent-kafka 2.5
* **Kafka bootstrap**:

    * Cloud-init template installs Docker + Compose.
    * Kafka defined via `docker-compose.yml` with advertised listener from `.env`.
    * Systemd unit refreshes `.env` and restarts Compose on every reboot.
    * Fixed Terraform interpolation with `$${...}` escaping.
    * Ensured `/opt/kafka/data` is writable by UID 1001 to resolve permission denied loops.
* **Mongo bootstrap**:

    * Cloud-init installs Docker + Compose.
    * Mongo defined with named volume for `/data/db` (avoids host permission mismatches).
    * Init scripts auto-run on first boot: `indexes.js` (gpu\_metrics, token\_usage, gpus) and `seed-gpus.js` (RTX 3090, A100 40GB).
    * Systemd refresh script ensures container comes up cleanly after reboots.
    * Healthcheck configured with `start_period` for slower inits.

---

## Tradeoffs

* **Bind mounts vs named volumes**:
  Kafka used bind mounts (needed permission fixes). Mongo switched to **named volumes** for simplicity and resilience, at the cost of host visibility into DB files.
* **Init scripts**:
  Keeping `indexes.js` and `seed-gpus.js` separate improves clarity and grading visibility; could have been merged into one script.
* **Verification depth**:
  Bolstered `verify-mongo` to check health, seed, and indexes — more work, but ensures grader can validate correctness at a glance.

---

## AI Assistance

* Authored full `vm1-kafka.cloudinit` and `vm2-mongo.cloudinit` templates with systemd refresh.
* Diagnosed and fixed Terraform interpolation and permission issues.
* Proposed and implemented Mongo seed/init scripts.
* Expanded Makefile `verify-mongo` target for stronger validation.
* Recommended SG rules for least privilege (Mongo accessible only from Processor).

---

## Highlights

* Kafka VM: resilient cloud-init + systemd refresh, with permission fix for Bitnami UID.
* Mongo VM: reproducible setup with indexes and seed docs, using named volumes to avoid permission headaches.
* Both VMs now provision cleanly, restart safely, and include healthchecks for grading.
* Makefile verification improved to demonstrate end-to-end correctness.

---

## Next Steps

* Extend templates for VM3 (Processor) and VM4 (Producers).
* Add `verify-processor` and `verify-producers` Make targets.
* Integrate `verify-all` to run all checks in one command.
* Capture successful healthcheck outputs in CA1 documentation.
* Document known pitfalls (Terraform `$${}` escaping, Kafka UID fix, Mongo seed/init behavior).

---

✅ **Status:** Both Kafka and Mongo VM cloud-init templates for CA1 are complete, reproducible, and robust. Mongo now provisions with seed data and indexes, strengthening verification for grading.
