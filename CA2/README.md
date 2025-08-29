# CA2 — Orchestrated (Kubernetes/Swarm)

Summary
- Run the same pipeline on an orchestrator. Example uses Kubernetes.
- StatefulSets for Kafka/Mongo; Deployment for Processor; Job/CronJob for Producers.

Replication (High-Level)
1) Create a cluster (kind, k3s, or managed free tier).
2) kubectl apply -f k8s/: NS, Secrets/ConfigMaps, Kafka SS, Mongo SS, Processor Deployment, Producers Job.
3) Optional Ingress/NodePort for /health.
4) Validate processor logs and Mongo collections.

Links
- Architecture diagram: ./architecture.md
- Conversation summary: ./conversation-summary.md