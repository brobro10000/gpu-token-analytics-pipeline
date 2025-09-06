# VM1 – Kafka (Bitnami, single-node KRaft)

Summary
- Runs a single-node Apache Kafka 3.7 (Bitnami image) in KRaft mode.
- Hosts the topics used by the pipeline: gpu.metrics.v1 and token.usage.v1.
- Persists broker data to a local Docker volume on the VM.

Configuration

| Category   | Details |
|------------|---------|
| Hardware   | Suggested instance: t3.small or t4g.small; ≈2 vCPU, 2–4 GB RAM (4–8 GB prod); ≈20 GB gp3 SSD; no GPU |
| Software   | Docker + bitnami/kafka:3.7; KRaft (no ZK); healthcheck via kafka-broker-api-versions.sh |
| Networking | Private IP (example): 10.0.1.197; Ports: 9092/tcp exposed; Controller 9093 internal; Advertised listener: PLAINTEXT://10.0.1.197:9092; Volume: ./data → /bitnami/kafka |

Networking notes
- Only VM3 (processor) and VM4 (producers) should be allowed to reach 9092.
- Security groups/UFW should restrict 9092 accordingly; SSH 22 allowed from admin only.

Makefile (brief)
- setup: Install Docker/Compose if missing and create ./data.
- up / down / restart / ps / logs / health: Lifecycle and status for the kafka container.
- topics / list-topics: Idempotently create and list gpu.metrics.v1 and token.usage.v1.
- send-metric / send-token: One-shot sample producers for quick smoke tests.
- consume-metric / consume-token: Console consumers for manual verification.
- wipe: docker compose down -v (removes local volumes).

Key variables
- KAFKA_BIND_ADDR (default 10.0.1.197) controls the advertised listener in docker-compose.
- BROKER defaults to ${KAFKA_BIND_ADDR}:9092.
- TOPIC_METRIC=gpu.metrics.v1, TOPIC_TOKEN=token.usage.v1.

Related files
- docker-compose.yml: bitnami/kafka:3.7 service, ports, healthcheck, data volume, advertised listeners.
- config/server.properties: additional server configuration (if used).
