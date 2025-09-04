# Conversation Summary — CA0

## Timeline of Milestones

| Date (UTC)        | Milestone / Topic                           | Key Decisions & Outcomes                                                                 |
|-------------------|---------------------------------------------|------------------------------------------------------------------------------------------|
| 2025-08-29 03:28  | Initial CA0 planning                        | Confirmed pipeline (Producers → Kafka → Processor → MongoDB), PlantUML for diagrams, 4 VMs. |
| 2025-09-02        | PlantUML debugging                          | Determined VS Code extension needs Graphviz (`dot`) for local render; offered server-render alternative. |
| 2025-09-03        | File structure design                       | Split into per-VM directories (`vm1-kafka`, `vm2-mongo`, `vm3-processor`, `vm4-producers`) with shared schemas/docs. |
| 2025-09-03        | Makefile scaffolding                        | Built root Makefile to manage Kafka lifecycle, topics, processor, producer, and cleanup.  |
| 2025-09-03        | Local dev verification                      | Ran processor + producer locally → Mongo stored 20 gpu_metrics docs and token_usage with `cost_per_token`. |
| 2025-09-03        | Kafka cluster.id mismatch                   | Resolved with cleanup of `/tmp/kraft-combined-logs`; suggested `.kafka-data` project-local dir + `make kafka-reset`. |
| 2025-09-04        | Documentation polish                        | Added `LOCAL_DEV.md`, config summary tables (local + 4-VM), cleanup commands, expected output. |
| 2025-09-04        | Git hygiene                                | Added `.gitignore` (Kafka logs, venvs, tarballs) and `.gitattributes` (normalize text, mark binaries). |

---

## Meta
- User: @brobro10000
- Space: Copilot Space grounded in madajaju/CS5287 and this repo.

## Request
- Guidance on building the CA0 pipeline locally before migrating into 4 VMs.
- Assistance debugging PlantUML extension in VS Code.
- Propose and refine file structure aligned with VM separation.
- Create Makefiles to replicate local runs (Kafka → Processor → Producer → MongoDB).
- Document cleanup and garbage collection flows for local testing.
- Generate a markdown guide for local development.
- Decide what artifacts to ignore in Git and define `.gitattributes`.
- Maintain a running “conversation summary” log of all AI-assisted design/build choices.

## Decisions
- **Pipeline**: Confirmed Producers → Kafka → Processor → MongoDB architecture, with cost_per_token computed in Processor and data stored in Mongo.
- **Local Testing**: Allowed a local dev workflow (manual installs or temporary make targets) but reaffirmed that official CA0 must be 4 VMs with Docker Compose inside the VMs.
- **File Structure**: Created per-VM folders (`vm1-kafka`, `vm2-mongo`, `vm3-processor`, `vm4-producers`) under `CA0/` with a shared `schemas/` and `demo/`.
- **Makefiles**: Root Makefile replicates local flow, provides `make up/down/status`, topic management, venv setup, producer/processor runners, and cleanup (`clean`, `gc`, `really-gc`).
- **Kafka Data**: Confirmed Kafka runtime data/logs should be in `.gitignore`.
- **Git Hygiene**: Added `.gitattributes` to enforce text normalization and mark binaries (images, video, tarballs, Kafka data) properly.
- **Docs**: Added `LOCAL_DEV.md` with prerequisites, step-by-step instructions, expected output, cleanup commands, and a config summary table (both local and 4-VM versions).
- **README**: Updated to include replication checklist, local dev guide, config summaries, and explicit notes on security (SSH key-only, UFW mirrors SGs).

## Tradeoffs
- **Kafka KRaft vs ZooKeeper**: Sticking with KRaft for local dev (simpler, no ZK). ZK optional for VM deployments.
- **GPU Metrics**: Real NVML/SMI integration optional; can seed with JSON to validate the pipeline when GPUs aren’t available.
- **Local vs VM**: Local Makefile/dev guide exists for developer convenience but must not be confused with required VM-based CA0 deliverable.

## AI Assistance
- Proposed fixes for PlantUML VS Code extension (server vs local render; Graphviz requirements).
- Designed per-VM file structure with rationale tied to CS5287 rubric.
- Authored a comprehensive Makefile with lifecycle management, cleanup, and garbage collection.
- Authored `.gitignore` and `.gitattributes` tailored for Kafka, Mongo, and Python dev.
- Drafted `LOCAL_DEV.md` and improved `README.md` with config summary tables.
- Provided exact commands for Kafka reset when cluster.id mismatch occurred.
- Ensured documentation aligns with CA0 rubric (Correctness, Security, Documentation, Reproducibility).

## Next
- For CA1: translate per-VM setup into IaC (Terraform/Ansible) while preserving logical pipeline and version pins.
- For CA2: migrate to PaaS (Kubernetes or Swarm) with declarative manifests.
- For CA3: layer in observability (logs, metrics, autoscaling, security hardening).
- For CA4: distribute across multiple sites/clouds with secure connectivity and failover.
