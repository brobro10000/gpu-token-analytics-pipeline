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
| **2025-09-21** | **Kafka VM cloud-init template creation** | Drafted `vm1-kafka.cloudinit` with Docker + Compose install, `.env` for `KAFKA_BIND_ADDR`, and Compose spec for Bitnami Kafka 3.7 (KRaft). Added idempotent topic creation.                                                        |
| **2025-09-21** | **Systemd Option 2 refresh unit**         | Implemented `kafka-env-refresh.service` + `/usr/local/bin/kafka-env-refresh.sh` to auto-populate `KAFKA_BIND_ADDR` via IMDS on every reboot and re-run `docker compose up -d`.                                                     |
| **2025-09-21** | **Terraform templatefile fixes**          | Hit `${...}` interpolation issue on `${KAFKA_BIND_ADDR:?missing}`. Fixed by escaping as `$${KAFKA_BIND_ADDR:?missing}` so Compose expands it, not Terraform.                                                                       |
| **2025-09-21** | **Debugging container health**            | Kafka container stuck `unhealthy`; logs showed `mkdir: cannot create directory '/bitnami/kafka/config': Permission denied`. Root cause: bind-mounted `/opt/kafka/data` not writable by container UID 1001.                         |
| **2025-09-21** | **Permissions fix for Kafka data**        | Added `chown -R 1001:1001 /opt/kafka/data` in refresh script to match Bitnami Kafka’s non-root UID.                                                                                                                                |
| **2025-09-21** | **Mongo VM cloud-init template creation** | Drafted `vm2-mongo.cloudinit` with Docker + Compose, named volume (`mongo_data`), init scripts (`indexes.js`, `seed-gpus.js`), and a systemd refresh unit. Healthcheck uses `start_period`.                                        |
| **2025-09-21** | **Mongo seed + verify flow**              | Seeded GPU docs (RTX 3090, A100 40GB) and created robust `verify-mongo` checking health, indexes, and seed counts.                                                                                                                 |
| **2025-09-21** | **Processor VM cloud-init template**      | Created VM3 cloud-init that installs Docker/Compose, writes `.env`, and defines Compose for the FastAPI processor. Added systemd refresh that builds image from Git subdir and waits for health.                                   |
| **2025-09-21** | **Build-from-Git method**                 | Switched to Docker’s remote build context (`repo.git#ref:subdir`) for VM3. Avoids rsync and user-data bloat, always builds from source.                                                                                            |
| **2025-09-21** | **Processor image & health**              | Python 3.12 slim with FastAPI 0.112, Uvicorn 0.30, confluent-kafka 2.5, pymongo 4.8. Healthcheck uses HTTP `/health`. Fixed “unhealthy” due to missing `curl` by switching to wget/Python probe.                                   |
| **2025-09-21** | **Service behavior & API**                | Processor consumes `gpu.metrics.v1`/`token.usage.v1`, writes to Mongo (`gpu_metrics`, `token_usage`), computes `cost_per_token`, exposes `/health` + `/gpu/info`.                                                                  |
| **2025-09-21** | **Exec/verify helpers**                   | Added generic `exec-vmX` Make targets that auto-resolve container IDs via `docker compose ps -q`. Expanded `verify-processor` to show env, reachability (nc), health history, and logs.                                            |
| **2025-09-21** | **Container naming fix**                  | Avoided brittle names by either setting `container_name: processor` or resolving with `docker compose ps -q processor` in Make.                                                                                                    |
| **2025-09-21** | **Producers VM (VM4) template**           | Implemented `vm4-producers.cloudinit` using build-from-Git (`CA0/vm4-producers`), one-shot Compose service (`restart: "no"`), explicit `container_name: producer`, and Python-socket healthcheck to Kafka (no curl dependency).    |
| **2025-09-21** | **Verify producers + triggering**         | Added `verify-producers` to show ps/logs/exit code and a `trigger-producers` command (Compose `up --no-build producer`). Confirmed successful run: “Loaded 2 seeds… Sent 40 records (all flushed).”                                |
| **2025-09-21** | **End-to-end workflow verifier**          | Authored `verify-workflow` Make target: checks processor health & topics, records Mongo baseline, triggers producer, asserts Mongo deltas ≥1, spot-checks `/gpu/info`, prints Kafka end offsets.                                   |
| **2025-09-21** | **TTY fix in scripts**                    | Fixed `the input device is not a TTY` by removing `-t` from `docker exec` in non-interactive SSH contexts (use plain or `-i` only).                                                                                                |
| **2025-09-21** | **Pre-clean safety cap**                  | Added step `0b` to `verify-workflow` to **drop collections** (`gpu_metrics`, `token_usage`, `gpus`) if any count exceeds a cap (default `MAX_DOCS=100`) before the run to keep the DB tidy for grading.                            |
| **2025-09-21** | **Successful end-to-end run**             | E2E verifier output showed processor healthy, topics present, producer sent 40 records, Mongo counts increased (e.g., 60→80), and `/gpu/info` returned data. Final banner: **Workflow verified end-to-end**.                       |

---

## Decisions

* **CA1 mirrors CA0** with Terraform-managed provisioning and cloud-init bootstraps across four VMs.
* **VM stacks**:

    * VM1: Kafka 3.7.0 (KRaft, Bitnami)
    * VM2: MongoDB 7.0.x
    * VM3: FastAPI 0.112 + Uvicorn 0.30 + confluent-kafka 2.5 + pymongo 4.8
    * VM4: Python 3.12 + confluent-kafka 2.5
* **Build strategy**: Build application images **from Git subdirs** on-boot (VM3/VM4), avoiding rsync and ensuring source-of-truth parity.
* **Resilience**: Option-2 systemd “refresh/run” units ensure services come back clean after stop/start and can be re-triggered idempotently.
* **Verification**: Strong Makefile targets for each VM plus an **E2E workflow** that proves Producer→Kafka→Processor→Mongo→API.

---

## Tradeoffs

* **Bind mounts vs named volumes**:

    * Kafka bind mount (needed explicit `chown 1001:1001`).
    * Mongo switched to **named volume** to avoid host-permission issues; less transparent but simpler.
* **Healthcheck tooling**: Avoid `curl` assumptions on slim images; prefer wget/Python/TCP socket probes.
* **One-shot vs long-running producers**: Kept producer one-shot for determinism in grading; could add a systemd **timer** if periodic data is desired.
* **Compose `version`**: Dropped to silence deprecation warnings in modern Compose.

---

## Highlights

* **All four VMs** provision cleanly with Docker/Compose via cloud-init.
* **VM1 Kafka** resilient with proper advertised listeners and topic creation.
* **VM2 Mongo** initialized with indexes + seed data; robust healthcheck.
* **VM3 Processor** builds from Git, exposes `/health` + `/gpu/info`, and writes computed metrics into Mongo.
* **VM4 Producer** builds from Git, sends deterministic batches, and exits with code 0.
* **E2E Verifier**: Single `make verify-workflow` demonstrates end-to-end correctness and includes a **pre-clean cap** to keep DB counts bounded for repeated runs.

---

## Next Steps

* Add a `verify-all` wrapper that runs `verify-kafka`, `verify-mongo`, `verify-processor`, then `verify-workflow` and prints a single PASS/FAIL banner.
* Optional: add a **systemd timer** on VM4 to auto-trigger the producer every N minutes.
* Consider switching Kafka to a **named volume** for parity with Mongo, or keep the `chown` guard in place.
* Add a small **CI check** that lints templates and Makefile targets (compose config, terraform validate, shellcheck).

---

✅ **Status:** CA1 is fully operational across Kafka, Mongo, Processor, and Producer. The **end-to-end workflow verification passes**, and helper targets cover day-2 ops (triggering producers, resetting Mongo, pre-clean caps, and health checks).
