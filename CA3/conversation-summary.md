# Conversation Summary — CA3

Context
- Add cloud-native operations features to enhance the Kubernetes deployment from CA2.

Decisions & Tradeoffs
- Prometheus + Grafana stack for metrics and visualization.
- Loki for log aggregation to complement metrics.
- HPA based on CPU/memory and custom metrics like TPS.
- NetworkPolicies for microsegmentation; PDBs for availability.

AI Assistance
- Copilot suggested ops tooling and resilience patterns.

Next
- Add multi-region and advanced networking in CA4.