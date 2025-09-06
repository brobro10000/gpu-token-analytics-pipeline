# VM3 – Processor (Kafka consumer + FastAPI)

Summary
- Consumes events from Kafka topics gpu.metrics.v1 and token.usage.v1.
- Computes simple throughput/cost metrics (cost_per_token using PRICE_PER_HOUR_USD) over a sliding window.
- Writes documents to MongoDB collections: gpu_metrics and token_usage.
- Exposes a small HTTP API for health (/health) and a helper endpoint (/gpu/info).

Configuration

| Category   | Details |
|------------|---------|
| Hardware   | Suggested instance: t3.micro or t4g.micro; ≈1 vCPU, ~1 GB RAM; ≈10 GB gp3 SSD; no GPU required (can read NVML/SMI if present) |
| Software   | Docker image built from python:3.12-slim; FastAPI 0.112.2; uvicorn 0.30.6; confluent-kafka 2.5.0; pymongo 4.8.0; runs as non-root UID/GID 10001; healthcheck on /health |
| Networking | Private IP (example): 10.0.1.112; Inbound: 8080/tcp (optional, admin-only); Outbound: Kafka 10.0.1.197:9092 and MongoDB 10.0.1.86:27017 |
| Env        | KAFKA_BOOTSTRAP, MONGO_URL, PRICE_PER_HOUR_USD (default 0.85), HOST (0.0.0.0), PORT (8080) |
| Ports      | 8080:8080 (HTTP) |
| Volumes    | None (state kept in external systems) |

Networking notes
- Allow inbound 8080 only from your admin IP for health checks; not required for normal pipeline operation.
- Ensure security groups/UFW allow VM3 → VM1 (9092) and VM3 → VM2 (27017).

Makefile (brief)
- setup: Install Docker/Compose if missing; add user to docker group; build image.
- build / up / down / restart / ps / logs: Lifecycle and status.
- wait: Poll /health until ready; health: curl /health; curl: curl /gpu/info.
- doctor: Quick reachability checks to Kafka and Mongo plus local /health.

Key topics & collections
- Consumes: gpu.metrics.v1, token.usage.v1.
- Writes to MongoDB DB ca0: collections gpu_metrics and token_usage; indexes auto-created.

Related files
- docker-compose.yml: service definition, env, ports, healthcheck.
- Dockerfile: Python base, FastAPI/uvicorn startup, non-root user.
- .env: default endpoints and PORT/price.
- app/main.py: consumer loop and HTTP routes.
- app/requirements.txt: pinned Python dependencies.
