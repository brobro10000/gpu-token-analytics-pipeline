# Conversation Summary — CA0

Meta
- Date: 2025-08-29 03:28:23 UTC
- User: @brobro10000
- Space: Copilot Space grounded in madajaju/CS5287 and this repo.

Request
- Open PR(s) tying course assignments to this GPU/token analytics pipeline and add architecture/README content.
- Ensure CA0–CA4 diagrams iterate complexity; update READMEs and include conversation summaries as siblings.

Decisions
- Keep the same logical pipeline (Producers → Kafka → Processor → MongoDB), per CS5287 guidance.
- Use PlantUML for diagrams (no-cost, versionable).
- CA0 runs on 4 VMs; processor computes cost_per_token; Mongo stores gpu_metrics and token_usage.
- Minimal ports, SSH key-only, non-root containers.

Tradeoffs
- Kafka KRaft vs. ZK: kept ZK for VM simplicity; can switch later.
- GPU metrics: NVML/SMI optional vs seed data for environments without GPUs.

AI Assistance
- Copilot proposed structure, diagrams, and replication steps; user confirmed "yes" to proceed in one consolidated PR.

Next
- Expand CA1–CA4 with IaC, K8s, ops, and multi-site connectivity in same PR.