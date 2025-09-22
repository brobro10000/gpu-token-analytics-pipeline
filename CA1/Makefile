# ------------------------------
# CA1 root Makefile (run from /ca1)
# Validates stack using PRIVATE IPs discovered from Terraform outputs
# ------------------------------

# --- Config you may override at call time ---
SSH_KEY      ?= ~/.ssh/ca0
SSH_USER     ?= ubuntu
SSH_OPTS   	 ?= -i $(SSH_KEY) -o StrictHostKeyChecking=no
AWS_PROFILE  ?= terraform
AWS_REGION   ?= us-east-1

# --- Helper: pull TF outputs (JSON) from ./terraform dir ---
TF_JSON := $(shell terraform -chdir=terraform output -json 2>/dev/null)

# --- Extract private IPs via jq ---
VM1_PRIV := $(shell echo '$(TF_JSON)' | jq -r '.instance_private_ips.value.vm1_kafka')
VM2_PRIV := $(shell echo '$(TF_JSON)' | jq -r '.instance_private_ips.value.vm2_mongo')
VM3_PRIV := $(shell echo '$(TF_JSON)' | jq -r '.instance_private_ips.value.vm3_processor')
VM4_PRIV := $(shell echo '$(TF_JSON)' | jq -r '.instance_private_ips.value.vm4_producers')

# --- Extract public IPs (for SSH hop). If null, we print a hint. ---
VM1_PUB := $(shell echo '$(TF_JSON)' | jq -r '.instance_public_ips.value.vm1_kafka // empty')
VM2_PUB := $(shell echo '$(TF_JSON)' | jq -r '.instance_public_ips.value.vm2_mongo // empty')
VM3_PUB := $(shell echo '$(TF_JSON)' | jq -r '.instance_public_ips.value.vm3_processor // empty')
VM4_PUB := $(shell echo '$(TF_JSON)' | jq -r '.instance_public_ips.value.vm4_producers // empty')

VM1_HOST := $(SSH_USER)@$(VM1_PUB)
VM2_HOST := $(SSH_USER)@$(VM2_PUB)
VM3_HOST := $(SSH_USER)@$(VM3_PUB)
VM4_HOST := $(SSH_USER)@$(VM4_PUB)

# --- Derived service endpoints (PRIVATE) ---
KAFKA_BOOTSTRAP := $(VM1_PRIV):9092
MONGO_URL       := mongodb://$(VM2_PRIV):27017/ca0
PROCESSOR_HEALTH:= http://$(VM3_PRIV):8080/health

# --- Common SSH command (adds some resilience) ---
define SSH
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i $(SSH_KEY) $(SSH_USER)@$(1)
endef

.PHONY: help print addrs env verify verify-kafka verify-mongo verify-mongo-expanded verify-processor verify-producers \
        verify-processor-expanded verify-producers verify-topics verify-mongo-doc smoke produce consume verify-workflow

help:
	@echo "CA1 validation helpers (using PRIVATE IPs from terraform outputs)"
	@echo
	@echo "make addrs             # print private & public IPs"
	@echo "make env               # print env exports for KAFKA_BOOTSTRAP / MONGO_URL"
	@echo "make verify            # run all service checks"
	@echo "make verify-kafka      # list topics on VM1 (expects bitnami kafka)"
	@echo "make verify-mongo      # ping mongod on VM2"
	@echo "make verify-mongo-expanded
	@echo "make verify-processor  # curl /health on VM3"
	@echo "make verify-processor-expanded
	@echo "make verify-producers  # tail logs on VM4"
	@echo "make smoke             # simple E2E: create topics (idempotent) + list"
	@echo
	@echo "Override SSH_KEY, SSH_USER, AWS_PROFILE, AWS_REGION as needed."

print: addrs

addrs:
	@echo "Private IPs:"
	@echo "  VM1 kafka     : $(VM1_PRIV)"
	@echo "  VM2 mongo     : $(VM2_PRIV)"
	@echo "  VM3 processor : $(VM3_PRIV)"
	@echo "  VM4 producers : $(VM4_PRIV)"
	@echo
	@echo "Public IPs (for SSH hop):"
	@echo "  VM1 kafka     : $(VM1_PUB)"
	@echo "  VM2 mongo     : $(VM2_PUB)"
	@echo "  VM3 processor : $(VM3_PUB)"
	@echo "  VM4 producers : $(VM4_PUB)"
	@if [ -z "$(VM1_PUB)$(VM2_PUB)$(VM3_PUB)$(VM4_PUB)" ]; then \
	  echo ""; \
	  echo "NOTE: Public IPs are null. Use a bastion or SSM Session Manager, or add a temporary public IP for validation."; \
	fi

env:
	@echo "export KAFKA_BOOTSTRAP=$(KAFKA_BOOTSTRAP)"
	@echo "export MONGO_URL=$(MONGO_URL)"
	@echo "export PROCESSOR_HEALTH=$(PROCESSOR_HEALTH)"

# --- Common SSH command (expects a full target like ubuntu@1.2.3.4) ---
define SSH
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i $(SSH_KEY) $(1)
endef

# Optional: ensure key permissions are safe (no-op if already 600)
.PHONY: fix-key-perms
fix-key-perms:
	@if [ -f "$(SSH_KEY)" ]; then chmod 600 "$(SSH_KEY)" || true; fi

# ------------------------------
# VALIDATION TARGETS
# ------------------------------
verify: verify-kafka verify-mongo verify-processor verify-producers
	@echo "All basic checks executed."

verify-kafka: fix-key-perms
	@if [ -z "$(VM1_PUB)" ]; then echo "VM1 public IP missing; cannot SSH. See 'make addrs'."; exit 1; fi
	@echo ">> VM1/Kafka: listing topics (using PRIVATE bootstrap $(KAFKA_BOOTSTRAP))"
	@$(call SSH,$(VM1_HOST)) 'docker ps && docker exec kafka kafka-topics.sh --list --bootstrap-server localhost:9092 || true'

verify-topics: verify-kafka

verify-mongo: fix-key-perms
	@if [ -z "$(VM2_PUB)" ]; then echo "VM2 public IP missing; cannot SSH. See 'make addrs'."; exit 1; fi
	@echo ">> VM2/Mongo: ping mongod"
	@$(call SSH,$(VM2_HOST)) 'docker ps && docker exec -i mongodb mongosh --quiet --eval "db.runCommand({ ping: 1 })" || true'

verify-mongo-expanded: fix-key-perms
	@if [ -z "$(VM2_PUB)" ]; then echo "VM2 public IP missing; cannot SSH. See 'make addrs'."; exit 1; fi
	@echo ">> VM2/Mongo: docker ps (basic status)"
	@$(call SSH,$(VM2_HOST)) 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

	@echo ">> VM2/Mongo: container health status"
	@$(call SSH,$(VM2_HOST)) 'docker inspect --format="{{.State.Health.Status}}" mongodb || echo "no-healthcheck"'

	@echo ">> VM2/Mongo: ping mongod"
	@$(call SSH,$(VM2_HOST)) 'docker exec -i mongodb mongosh --quiet --eval "db.runCommand({ ping: 1 })" || true'

	@echo ">> VM2/Mongo: list databases"
	@$(call SSH,$(VM2_HOST)) 'docker exec -i mongodb mongosh --quiet --eval "db.adminCommand({ listDatabases: 1 }).databases" || true'

	@echo ">> VM2/Mongo: check GPU seed docs"
	@$(call SSH,$(VM2_HOST)) 'docker exec -i mongodb mongosh ca1 --quiet --eval "db.gpus.find().pretty()" || true'

	@echo ">> VM2/Mongo: check indexes"
	@$(call SSH,$(VM2_HOST)) 'docker exec -i mongodb mongosh ca1 --quiet --eval "printjson(db.gpu_metrics.getIndexes()); printjson(db.token_usage.getIndexes()); printjson(db.gpus.getIndexes());" || true'


verify-processor: fix-key-perms
	@if [ -z "$(VM3_PUB)" ]; then echo "VM3 public IP missing; cannot SSH. See 'make addrs'."; exit 1; fi
	@echo ">> VM3/Processor: health check (curl localhost since service binds on 8080)"
	@$(call SSH,$(VM3_HOST)) 'curl -sf http://localhost:8080/health || (echo "health check failed" && exit 1)'

verify-processor-expanded: fix-key-perms
	@if [ -z "$(VM3_PUB)" ]; then echo "VM3 public IP missing; cannot SSH. See 'make addrs'."; exit 1; fi
	@echo ">> VM3/Processor: docker ps (status/ports)"
	@$(call SSH,$(VM3_HOST)) 'docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'

	@echo ">> VM3/Processor: container health status"
	@$(call SSH,$(VM3_HOST)) 'docker inspect --format="{{.State.Health.Status}}" processor 2>/dev/null || echo "no-healthcheck"'

	@echo ">> VM3/Processor: health endpoint"
	@$(call SSH,$(VM3_HOST)) 'curl -sf http://localhost:8080/health || (echo "health check failed" && exit 1)'

	@echo ">> VM3/Processor: show runtime env (.env)"
	@$(call SSH,$(VM3_HOST)) 'echo "--- /opt/processor/.env ---"; sed -n "1,120p" /opt/processor/.env || true'

	@echo ">> VM3/Processor: resolve Kafka & Mongo from .env"
	@$(call SSH,$(VM3_HOST)) 'KAFKA=$$(sed -n "s/^KAFKA_BOOTSTRAP=\\(.*\\)/\\1/p" /opt/processor/.env); echo "KAFKA_BOOTSTRAP=$$KAFKA"; \
	                           MONGO=$$(sed -n "s/^MONGO_URL=\\(.*\\)/\\1/p" /opt/processor/.env); echo "MONGO_URL=$$MONGO"'

	@echo ">> VM3/Processor: reachability checks (nc) to Kafka & Mongo"
	@$(call SSH,$(VM3_HOST)) 'set -e; \
	  KAFKA=$$(sed -n "s/^KAFKA_BOOTSTRAP=\\(.*\\)/\\1/p" /opt/processor/.env); \
	  KHOST=$${KAFKA%:*}; KPORT=$${KAFKA##*:}; \
	  echo "Probing Kafka $$KHOST:$$KPORT"; nc -zv -w2 "$$KHOST" "$$KPORT"; \
	  MONGO=$$(sed -n "s/^MONGO_URL=mongodb:\\/\\/\\([^:]*\\):\\([0-9]*\\).*/\\1 \\2/p" /opt/processor/.env); \
	  set -- $$MONGO; MH=$$1; MP=$$2; echo "Probing Mongo $$MH:$$MP"; nc -zv -w2 "$$MH" "$$MP"; true'

	@echo ">> VM3/Processor: confirm process is listening on 8080"
	@$(call SSH,$(VM3_HOST)) 'ss -ltnp | grep ":8080" || (echo "nothing listening on 8080" && exit 1)'

	@echo ">> VM3/Processor: GET /gpu/info (best-effort)"
	@$(call SSH,$(VM3_HOST)) 'curl -sf http://localhost:8080/gpu/info || true'

	@echo ">> VM3/Processor: container user & image (sanity)"
	@$(call SSH,$(VM3_HOST)) 'docker inspect --format="User={{.Config.User}} Image={{.Config.Image}}" processor || true'

	@echo ">> VM3/Processor: recent logs (last 120 lines)"
	@$(call SSH,$(VM3_HOST)) 'docker logs --tail=120 processor || true'

	@echo ">> VM3/Processor: if unhealthy, dump full health details"
	@$(call SSH,$(VM3_HOST)) 'HS=$$(docker inspect --format="{{.State.Health.Status}}" processor 2>/dev/null || echo "unknown"); \
	  if [ "$$HS" != "healthy" ]; then echo "--- Healthcheck JSON ---"; docker inspect processor | sed -n "1,200p"; fi || true'

verify-producers: fix-key-perms
	@if [ -z "$(VM4_PUB)" ]; then echo "VM4 public IP missing; cannot SSH. See 'make addrs'."; exit 1; fi
	@echo ">> VM4/Producers: recent logs"
	@$(call SSH,$(VM4_HOST)) 'docker ps && docker logs --tail=100 producer || true'

# verify-workflow: End-to-end check with pre-clean if counts exceed a cap
# Usage: make verify-workflow [MAX_DOCS=100]
verify-workflow: fix-key-perms
	@if [ -z "$(VM1_PUB)$(VM2_PUB)$(VM3_PUB)$(VM4_PUB)" ]; then echo "Missing VM public IPs; run 'make addrs' first."; exit 1; fi

	@echo "=== 0) Preflight: Processor health and topics exist ==="
	@$(call SSH,$(VM3_HOST)) 'curl -sf http://localhost:8080/health && echo "Processor healthy ✅"'
	@$(call SSH,$(VM1_HOST)) 'docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list | egrep -E "gpu\.metrics\.v1|token\.usage\.v1"'

	@echo "=== 0b) Enforce Mongo cap before run (default MAX_DOCS=100) ==="
	@$(call SSH,$(VM2_HOST)) 'DB=ca1; MAX=$${MAX_DOCS:-100}; \
	  GM=$$(docker exec -i mongodb mongosh --quiet --eval "db.getSiblingDB(\"$$DB\").gpu_metrics.countDocuments()"); \
	  TU=$$(docker exec -i mongodb mongosh --quiet --eval "db.getSiblingDB(\"$$DB\").token_usage.countDocuments()"); \
	  GP=$$(docker exec -i mongodb mongosh --quiet --eval "db.getSiblingDB(\"$$DB\").gpus.countDocuments()"); \
	  echo "Counts: gpu_metrics=$$GM token_usage=$$TU gpus=$$GP (cap=$$MAX)"; \
	  if [ $$GM -gt $$MAX ] || [ $$TU -gt $$MAX ] || [ $$GP -gt $$MAX ]; then \
	    echo "Cap exceeded → dropping collections gpu_metrics, token_usage, gpus"; \
	    docker exec -i mongodb mongosh --quiet --eval "const d=db.getSiblingDB(\"$$DB\"); d.gpu_metrics.drop(); d.token_usage.drop(); d.gpus.drop(); print(\"dropped\")"; \
	    sleep 2; \
	  else \
	    echo "Counts within cap → no reset"; \
	  fi'

	@echo "=== 1) Baseline Mongo counts (before) ==="
	@$(call SSH,$(VM2_HOST)) 'docker exec -i mongodb mongosh --quiet --eval "db.getSiblingDB(\"ca1\").gpu_metrics.countDocuments()" > /tmp/gpu_before.txt'
	@$(call SSH,$(VM2_HOST)) 'docker exec -i mongodb mongosh --quiet --eval "db.getSiblingDB(\"ca1\").token_usage.countDocuments()" > /tmp/tok_before.txt'
	@$(call SSH,$(VM2_HOST)) 'echo "gpu_metrics(before)=$$(cat /tmp/gpu_before.txt)"; echo "token_usage(before)=$$(cat /tmp/tok_before.txt)"'

	@echo "=== 2) Trigger producer one-shot ==="
	@$(call SSH,$(VM4_HOST)) 'cd /opt/producers && docker compose up --no-build producer --abort-on-container-exit || true'
	@$(call SSH,$(VM4_HOST)) 'CID=$$(docker compose -f /opt/producers/docker-compose.yml ps -q producer); \
	  if [ -n "$$CID" ]; then \
	    EC=$$(docker inspect --format="{{.State.ExitCode}}" $$CID 2>/dev/null || echo "N/A"); \
	    echo "Producer ExitCode=$$EC"; docker logs --tail=60 $$CID || true; \
	  else echo "Producer container not found"; fi'

	@echo "=== 3) Give the processor a moment to consume & write ==="
	@sleep 4

	@echo "=== 4) Mongo counts (after) + delta assertions ==="
	@$(call SSH,$(VM2_HOST)) 'docker exec -i mongodb mongosh --quiet --eval "db.getSiblingDB(\"ca1\").gpu_metrics.countDocuments()" > /tmp/gpu_after.txt'
	@$(call SSH,$(VM2_HOST)) 'docker exec -i mongodb mongosh --quiet --eval "db.getSiblingDB(\"ca1\").token_usage.countDocuments()" > /tmp/tok_after.txt'
	@$(call SSH,$(VM2_HOST)) 'GPU_B=$$(cat /tmp/gpu_before.txt); GPU_A=$$(cat /tmp/gpu_after.txt); \
	  TOK_B=$$(cat /tmp/tok_before.txt); TOK_A=$$(cat /tmp/tok_after.txt); \
	  echo "gpu_metrics(after)=$$GPU_A (before=$$GPU_B)"; echo "token_usage(after)=$$TOK_A (before=$$TOK_B)"; \
	  test $$(($$GPU_A-$$GPU_B)) -ge 1 && echo "gpu_metrics delta OK ✅" || { echo "gpu_metrics did not increase ❌"; exit 1; }; \
	  test $$(($$TOK_A-$$TOK_B)) -ge 1 && echo "token_usage delta OK ✅" || { echo "token_usage did not increase ❌"; exit 1; }'

	@echo "=== 5) Processor API spot-check ==="
	@$(call SSH,$(VM3_HOST)) 'curl -sf http://localhost:8080/gpu/info | sed -e "s/.*/sample: &/;q" || true'

	@echo "=== ✅ Workflow verified end-to-end ==="


ssh-kafka:     ; @ssh $(SSH_OPTS) $(SSH_USER)@$(VM1_PUB)
ssh-mongo:     ; @ssh $(SSH_OPTS) $(SSH_USER)@$(VM2_PUB)
ssh-processor: ; @ssh $(SSH_OPTS) $(SSH_USER)@$(VM3_PUB)
ssh-producers: ; @ssh $(SSH_OPTS) $(SSH_USER)@$(VM4_PUB)

# ------------------------------
# Simple smoke: ensure topics exist then list (idempotent)
# ------------------------------
smoke:
	@if [ -z "$(VM1_PUB)" ]; then echo "VM1 public IP missing; cannot SSH. See 'make addrs'."; exit 1; fi
	@echo ">> Creating topics if not exists on VM1 then listing"
	@$(call SSH,$(VM1_PUB)) '\
	  docker exec kafka kafka-topics.sh --create --if-not-exists --topic gpu.metrics.v1   --bootstrap-server localhost:9092; \
	  docker exec kafka kafka-topics.sh --create --if-not-exists --topic token.usage.v1  --bootstrap-server localhost:9092; \
	  docker exec kafka kafka-topics.sh --list --bootstrap-server localhost:9092 \
	'
