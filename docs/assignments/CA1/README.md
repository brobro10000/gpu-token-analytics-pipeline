# CA1 — IaC Rebuild (Same Topology, Automated)

Summary
- Recreate CA0 using IaC (Terraform/Ansible or similar), idempotent with secure secret management.
- Pipeline unchanged; processor still computes cost_per_token.

Replication (High-Level)
1) Install Terraform/Ansible; configure cloud creds via env/SM.
2) make deploy: create VPC/SG/VMs; install Kafka, Mongo; deploy processor/producers.
3) make test: produce sample; verify Mongo gpu_metrics and token_usage.
4) make destroy: remove all resources cleanly.

Links
- Architecture diagram: ./architecture.md
- Conversation summary: ./conversation-summary.md