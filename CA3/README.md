# CA3 — Cloud-Native Ops

Summary
- Add observability (Prometheus, Grafana, logs), HPA for Processor, NetworkPolicies, PDBs, and resilience drills.

Replication (High-Level)
1) Deploy Prometheus/Grafana/Loki (helm or manifests).
2) Expose /metrics from Processor; create dashboards for TPS, cost_per_token, GPU utilization.
3) Configure HPA, NetworkPolicies, PDBs.
4) Run a chaos drill; validate recovery per runbook.

Links
- Architecture diagram: ./architecture.md
- Conversation summary: ./conversation-summary.md