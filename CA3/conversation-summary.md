# Conversation Summary — CA3

Meta
- Date: 2025-08-29 03:58:24 UTC
- User: @brobro10000
- Context: Add ops features to CA3 diagram: observability, autoscaling, security, resilience.

Request
- Incorporate Prometheus, Grafana, and logs collector; show HPA, NetworkPolicies, and PDBs; include Chaos component.

Decisions
- Keep observability in a separate namespace for clarity.
- Expose /metrics from Processor and model HPA scaling signals (CPU/QPS) in the diagram text.

Tradeoffs
- Loki vs. ELK: choose generic label (Loki/ELK) to allow either stack.
- HPA based on CPU to start; custom metrics later.

AI Assistance
- Copilot used CS5287 CA3 deliverables list to ensure all required elements appear in the diagram and notes.

Next
- Add alert rules and dashboard JSON in a future iteration; keep this PR documentation-only.