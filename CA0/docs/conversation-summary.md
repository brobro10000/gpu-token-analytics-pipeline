# Conversation Summary — CA0

## Timeline of Milestones

| Date (UTC)       | Milestone / Topic              | Key Decisions & Outcomes                                                                                                                                                        |
| ---------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2025-08-29 03:28 | Initial CA0 planning           | Confirmed pipeline (Producers → Kafka → Processor → MongoDB), PlantUML for diagrams, 4 VMs.                                                                                     |
| 2025-09-02       | PlantUML debugging             | Determined VS Code extension needs Graphviz (`dot`) for local render; offered server-render alternative.                                                                        |
| 2025-09-03       | File structure design          | Split into per-VM directories (`vm1-kafka`, `vm2-mongo`, `vm3-processor`, `vm4-producers`) with shared schemas/docs.                                                            |
| 2025-09-03       | Makefile scaffolding           | Built root Makefile to manage Kafka lifecycle, topics, processor, producer, and cleanup.                                                                                        |
| 2025-09-03       | Local dev verification         | Ran processor + producer locally → Mongo stored 20 gpu\_metrics docs and token\_usage with `cost_per_token`.                                                                    |
| 2025-09-03       | Kafka cluster.id mismatch      | Resolved with cleanup of `/tmp/kraft-combined-logs`; suggested `.kafka-data` project-local dir + `make kafka-reset`.                                                            |
| 2025-09-04       | Documentation polish           | Added `LOCAL_DEV.md`, config summary tables (local + 4-VM), cleanup commands, expected output.                                                                                  |
| 2025-09-04       | Git hygiene                    | Added `.gitignore` (Kafka logs, venvs, tarballs) and `.gitattributes` (normalize text, mark binaries).                                                                          |
| **2025-09-05**   | **VM1 bootstrap & sync**       | Fixed SSH quoting; stabilized `ssh-run`/`rsync-repo`; added rsync **excludes** to avoid touching service data dirs.                                                             |
| **2025-09-05**   | **VM2 Mongo bring-up**         | Clean Makefile (`setup/up/wait/ping/stats/init-indexes/shell/logs/down/down-v`), corrected **service-name mismatch** (`mongo` vs `container_name`), suggested **named volume**. |
| **2025-09-05**   | **Networking (VM3 → VM2)**     | Diagnosed Mongo timeouts → **Security Group** missing 27017 from VM3; documented SG fix, optional **UFW** rule, `nc -w` probes, and `tcpdump` verification.                     |
| **2025-09-05**   | **VM3 Processor (dockerized)** | `.env` + healthcheck; Makefile `setup` now **installs Docker+Compose** if missing, then builds; added `doctor` and `wait`.                                                      |
| **2025-09-05**   | **VM4 Producers (one-shot)**   | Containerized producer with `.env`; Makefile `setup/build/up/doctor`; root wrappers to run once and tail logs.                                                                  |
| **2025-09-05**   | **End-to-end validation path** | Runbook: VM1 topics → VM3 up/wait → VM4 run → VM2 stats → (optional) VM3 `/gpu/info` spot-check.                                                                                |

---

## Meta

* User: @brobro10000
* Space: Copilot Space grounded in madajaju/CS5287 and this repo.
* This file extends the previously maintained summary with today’s additions.&#x20;

## Request

* Guidance on building the CA0 pipeline locally before migrating into 4 VMs.
* Assistance debugging PlantUML extension in VS Code.
* Propose and refine file structure aligned with VM separation.
* Create Makefiles to replicate local runs (Kafka → Processor → Producer → MongoDB).
* Document cleanup and garbage collection flows for local testing.
* Generate a markdown guide for local development.
* Decide what artifacts to ignore in Git and define `.gitattributes`.
* Maintain a running “conversation summary” log of all AI-assisted design/build choices.

## Decisions

* **Pipeline**: Confirmed Producers → Kafka → Processor → MongoDB architecture, with `cost_per_token` computed in the Processor and data stored in Mongo.
* **Local Testing**: Kept a local dev workflow but reaffirmed that the official CA0 deliverable runs on **4 VMs** with Docker Compose inside the VMs.
* **File Structure**: Per-VM folders under `CA0/` (`vm1-kafka`, `vm2-mongo`, `vm3-processor`, `vm4-producers`) with shared artifacts as needed.
* **Makefiles**: Root Makefile orchestrates per-VM targets via SSH; per-VM Makefiles provide `setup/up/wait/logs` (and service-specific helpers).
* **Kafka Data**: Runtime data/logs excluded from VCS and rsync; prefer **named volumes** for services with on-disk state.
* **Docs**: `LOCAL_DEV.md` + expanded `README` with config summaries (local & 4-VM), security notes, and cleanup guidance.

## Tradeoffs

* **KRaft vs ZooKeeper**: Stay on KRaft (no ZK) for simplicity.
* **Native vs Dockerized Processor**: Native (venv + systemd) is lighter; we chose **dockerized** for consistency with other VMs and easy remote ops.
* **Bind mounts vs Named volumes**: Bind mounts are inspectable but cause host-perm issues; **named volumes** preferred for Mongo/Kafka.

## AI Assistance

* Fixed brittle SSH/quoting; simplified remote env handling (prefer runtime env injection over editing `.env` inline).
* Authored/cleaned per-VM Makefiles and Compose files with **idempotent** bring-up and health/doctor checks.
* Added rsync excludes to avoid deleting DB files; provided safe `wipe-data` flow.
* Diagnosed Mongo timeouts to **Security Groups**; added UFW guidance, `nc -w` probes, and `tcpdump` tips.
* Produced dockerized VM3/VM4 setups with `.env`, healthchecks, and doctor targets.
* Wrote verification runbooks for Kafka topics, processor health, producer runs, and Mongo counts.

---

## **Highlights from 2025-09-05 (Key Points)**

* **rsync hygiene**

    * Excluded `CA0/**/data/**` and `CA0/**/mongo-data/**` from sync to prevent permission errors and accidental deletions.
    * Encouraged named volumes for stateful services.
* **VM2 service-name mismatch**

    * Compose service key was `mongo` while `container_name` was `mongodb`; aligned **Makefile commands to the service name**.
* **Mongo connectivity (VM3 → VM2)**

    * Root cause: **missing SG inbound 27017** on VM2 for VM3.
    * Fix: SG rule to allow 27017 from VM3’s SG (or private CIDR); optional UFW allow from `10.0.1.112`; verify with `nc -zv -w 2`.
* **VM3 Processor (dockerized)**

    * `.env` driven config; healthcheck on `/health`.
    * `make setup` auto-installs Docker + Compose if absent; added `doctor` and `wait`.
* **VM4 Producer**

    * One-shot container with `.env` override for `KAFKA_BOOTSTRAP` (VM1 private IP).
    * `doctor` target to confirm Kafka reachability before sending.
* **End-to-end validation**

    * Sequence defined: VM1 topics → VM3 up/wait → VM4 run → VM2 stats; optional API check `/gpu/info`.

---

## Next

* Finalize SG rules using **SG-to-SG** references (least privilege).
* Standardize **named volumes** for Mongo/Kafka.
* Add Kafka **consumer-group** lag command on VM1 to monitor processor consumption.
* Optional: Terraform/Ansible for SG and per-VM bootstrap; CI lint for Compose/Makefiles.

---

**Status:** CA0 is runnable across 4 VMs with deterministic Makefiles/Compose, private-IP wiring, and verifiable E2E flow. The primary blocker encountered today (Mongo SG) is resolved by allowing TCP 27017 from the processor VM’s security group.
