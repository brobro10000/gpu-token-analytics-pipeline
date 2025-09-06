# VM4 – Producers (Kafka event generators)

Summary
- Generates synthetic events to Kafka for pipeline testing: GPU metrics and token-usage records.
- Reads seed GPU metadata from gpu_seed.json; for each batch iteration sends one gpu.metrics.v1 and one token.usage.v1 message.
- One-shot container by default (exits when done); can be re-run to generate more traffic.

Configuration

| Category   | Details |
|------------|---------|
| Hardware   | Suggested instance: t3.micro or t4g.micro; ≈1 vCPU, ~1 GB RAM; ≈10 GB gp3 SSD; no GPU |
| Software   | Docker image built from python:3.12-slim; confluent-kafka 2.5.0; runs as non-root UID/GID 10001; restart: "no" (one-shot); simple TCP healthcheck to Kafka |
| Networking | Private IP (example): 10.0.1.85; Outbound only to Kafka at 10.0.1.197:9092; No inbound ports exposed |
| Env        | KAFKA_BOOTSTRAP (e.g., 10.0.1.197:9092); GPU_SEED (/data/gpu_seed.json); BATCH (default 20); SLEEP_SEC (default 0.5); TOPIC_METRIC (gpu.metrics.v1); TOPIC_TOKEN (token.usage.v1); HOSTNAME (vm4) |
| Ports      | None |
| Volumes    | Seed file baked-in: gpu_seed.json → /data/gpu_seed.json (override via GPU_SEED if desired) |

Topics
- Produces to: gpu.metrics.v1 and token.usage.v1.

Networking notes
- VM4 requires egress to VM1:9092 only. Lock down inbound traffic (SSH 22 from admin IP only).

Makefile (brief)
- setup: Install Docker/Compose if missing and build the image.
- build: Build image.
- up / run-once: Run the producer until the configured batch completes (container exits when done).
- logs / ps / down / restart: Standard lifecycle and logs.
- doctor: Quick TCP reachability check to the configured Kafka bootstrap.

Key variables
- KAFKA (in Makefile) defaults from .env or falls back to 10.0.1.197:9092 for doctor checks.

Related files
- docker-compose.yml: one-shot service with env, user, and healthcheck.
- Dockerfile: Python base, copies producer.py and gpu_seed.json.
- requirements.txt: confluent-kafka dependency.
- producer.py: generates and publishes events.
- gpu_seed.json: seed data used for gpu.metrics.v1 messages.
