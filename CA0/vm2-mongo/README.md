# VM2 – MongoDB (single node)

Summary
- Stores pipeline data in MongoDB 7.0: gpu_metrics and token_usage collections.
- Initializes indexes automatically from ./config/init-scripts/indexes.js on first start.
- Intended to be reachable only from VM3 (processor) on port 27017 within the VPC.

Configuration

| Category   | Details |
|------------|---------|
| Hardware   | Suggested instance: t3.small or t4g.small; ≈2 vCPU, 2–4+ GB RAM; ≈30 GB gp3 SSD; no GPU |
| Software   | Docker + mongo:7.0; healthcheck via mongosh ping; init scripts mounted read-only to /docker-entrypoint-initdb.d |
| Networking | Private IP (example): 10.0.1.86; Port: 27017/tcp exposed to VPC; Access: allow from VM3 only; Collections: gpu_metrics, token_usage |
| Volumes    | Named volume mongo_data → /data/db; ./config/init-scripts → /docker-entrypoint-initdb.d:ro |

Makefile (brief)
- setup: Install Docker/Compose if missing.
- up / down / down-v / restart / ps / logs: Lifecycle and status.
- wait / ping: Wait for readiness; run db.adminCommand('ping').
- init-indexes: Apply indexes.js (idempotent).
- stats: Print document counts for gpu_metrics and token_usage in DB ca0.
- shell: Open interactive mongosh in the container.
- fix-perms: Utility in case of host-dir data usage (not needed with named volume).

Key variables
- DB=ca0; SERVICE=mongo; MONGO=mongosh.

Related files
- docker-compose.yml: mongo:7.0 service, port 27017, healthcheck, volumes.
- config/init-scripts/indexes.js: creates indexes on gpu_metrics and token_usage.
