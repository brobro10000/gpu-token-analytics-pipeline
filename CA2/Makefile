# ------------------------------
# CA2 root Makefile (run from /ca2)
# Validates stack using PRIVATE IPs discovered from Terraform outputs
# ------------------------------

# --- Config you may override at call time ---
SSH_KEY      ?= ~/.ssh/ca0
SSH_USER     ?= ubuntu
SSH_OPTS   	 ?= -i $(SSH_KEY) -o StrictHostKeyChecking=no

KUBECONFIGL ?= .kube/kubeconfig.yaml
K8S_DIR     ?= k8s
KUBECTL_OPTS ?=

AWS_PROFILE  ?= terraform
AWS_REGION   ?= us-east-1

# --- Helper: pull TF outputs (JSON) from ./terraform dir ---
TF_JSON := $(shell terraform -chdir=terraform output -json 2>/dev/null)

# ================== Cluster outputs ==================
# Control-plane public IP (for SSH + kubeconfig copy)
CP_PUB   := $(shell echo '$(TF_JSON)' | jq -r '.control_plane_public_ip.value // empty')
REMOTE_KUBECONFIG  := $(shell echo '$(TF_JSON)' | jq -r '.remote_kubeconfig_path.value // empty')

# Workers (private IPs; we hop via the control-plane)
W1_PRIV  := $(shell echo '$(TF_JSON)' | jq -r '.worker_private_ips.value[0] // empty')
W2_PRIV  := $(shell echo '$(TF_JSON)' | jq -r '.worker_private_ips.value[1] // empty')

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

# ---------- Core commands ----------
ensure-tf:
	@terraform -chdir=terraform output >/dev/null 2>&1 || \
	  (echo "Run 'terraform apply' in ./terraform first." && exit 1)

ensure-kubeconfig:
	@[ -s "$(KUBECONFIGL)" ] || (echo "Local kubeconfig not found. Run 'make kubeconfig'." && exit 1)


# --- Common SSH command (adds some resilience) ---

.PHONY: help print addrs env fix-key-perms \
        verify verify-kafka verify-topics verify-mongo verify-mongo-expanded \
        verify-processor verify-processor-expanded verify-producers verify-workflow \
        ssh-kafka ssh-mongo ssh-processor ssh-producers ssh-control-plane ssh-worker1 ssh-worker2 \
        bootstrap-k3s tunnel kubeconfig kubectl-test status clean-kubeconfig \
        get-token join-worker-1 join-worker-2 join-workers smoke ensure-tf ensure-kubeconfig \
        addrs env print help put-key

help:
	@echo "CA2: cluster and validation helpers"
	@echo
	@echo "Terraform/outputs:"
	@echo "  make addrs                - Print private and public IPs from terraform outputs"
	@echo "  make env                  - Print env exports (KAFKA_BOOTSTRAP, MONGO_URL, PROCESSOR_HEALTH)"
	@echo
	@echo "Kubernetes:"
	@echo "  make kubeconfig           - Copy kubeconfig from control-plane"
	@echo "  make status               - kubectl get nodes and pods (requires KUBECONFIG)"
	@echo "  make kubectl-test         - Quick kubectl get nodes"
	@echo "  make clean-kubeconfig     - Remove local kubeconfig"
	@echo "  make tunnel               - SSH port-forward 6443 to control-plane"
	@echo
	@echo "SSH convenience:"
	@echo "  make ssh-control-plane    - SSH to control-plane"
	@echo "  make ssh-worker1|ssh-worker2 - SSH to workers via control-plane"
	@echo "  make ssh-kafka|ssh-mongo|ssh-processor|ssh-producers - SSH to legacy VMs (if enabled)"
	@echo
	@echo "Cluster helpers:"
	@echo "  make get-token            - Fetch K3s server token from control-plane"
	@echo "  make join-worker-1|join-worker-2|join-workers - Join worker(s) to control-plane"
	@echo
	@echo "Validation:"
	@echo "  make verify               - Run all service checks"
	@echo "  make verify-kafka|verify-mongo|verify-processor|verify-producers"
	@echo "  make verify-workflow      - End-to-end check"
	@echo "  make smoke                - Create topics and list (idempotent)"
	@echo
	@echo "Environment overrides: SSH_KEY=$(SSH_KEY) SSH_USER=$(SSH_USER) AWS_PROFILE=$(AWS_PROFILE) AWS_REGION=$(AWS_REGION)"

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
fix-key-perms:
	@if [ -f "$(SSH_KEY)" ]; then chmod 600 "$(SSH_KEY)" || true; fi

put-key:
	@[ -n "$(CP_PUB)" ] || (echo "control_plane_public_ip missing; run terraform apply."; exit 1)
	@echo "🔐 Copying local key $(SSH_KEY) to control plane..."
	@scp $(SSH_OPTS) $(SSH_KEY) $(SSH_USER)@$(CP_PUB):~/.ssh/ca0
	@ssh $(SSH_OPTS) $(SSH_USER)@$(CP_PUB) 'chmod 600 ~/.ssh/ca0 && echo "✅ Key installed at ~/.ssh/ca0"'

# ------------------------------
# KUBECTL Wrapper (shortcut for arbitrary commands)
# ------------------------------
# Usage: make K ARGS="get pods -A -o wide"
.PHONY: K
K: ensure-kubeconfig
	@KUBECONFIG=$(KUBECONFIGL) kubectl $(ARGS)

# ------------------------------
# VERIFY TARGETS
# ------------------------------
.PHONY: verify-all verify-kafka verify-mongo verify-processor verify-producers

verify-all: verify-kafka verify-mongo verify-processor verify-producers
	@echo "✅ All verify checks executed."

# --- Kafka ---
verify-kafka:
	@echo "🔎 [Kafka] StatefulSet + Pods"
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n platform get sts kafka || true
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n platform get pods -l app=kafka -o wide || true
	@echo "🪵 [Kafka] Recent logs"
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n platform logs -l app=kafka --tail=40 || true
	@echo "🧩 [Kafka] Service info"
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n platform get svc kafka -o wide || true

# --- Mongo ---
verify-mongo:
	@echo "🔎 [Mongo] StatefulSet + Pods"
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n platform get sts mongo || true
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n platform get pods -l app=mongo -o wide || true
	@echo "🪵 [Mongo] Recent logs"
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n platform logs -l app=mongo --tail=40 || true
	@echo "🧩 [Mongo] Service info"
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n platform get svc mongo -o wide || true

# --- Processor ---
verify-processor:
	@echo "🔎 [Processor] Deployment + Pods"
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n app get deploy processor || true
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n app get pods -l app=processor -o wide || true
	@echo "🪵 [Processor] Recent logs"
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n app logs -l app=processor --tail=40 || true
	@echo "🌐 [Processor] Health endpoint"
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n app exec -it $$(KUBECONFIG=$(KUBECONFIGL) kubectl -n app get pod -l app=processor -o name | head -n 1) -- \
		curl -sf http://localhost:8080/health || echo "Health check failed" || true

# --- Producers ---
verify-producers:
	@echo "🔎 [Producers] Deployment + Pods"
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n app get deploy producers || true
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n app get pods -l app=producers -o wide || true
	@echo "🪵 [Producers] Recent logs"
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n app logs -l app=producers --tail=40 || true

# verify-workflow: End-to-end check with pre-clean if counts exceed a cap
# Usage: make verify-workflow [MAX_DOCS=100]
verify-workflow: fix-key-perms
	@if [ -z "$(VM1_PUB)$(VM2_PUB)$(VM3_PUB)$(VM4_PUB)" ]; then echo "Missing VM public IPs; run 'make addrs' first."; exit 1; fi

	@echo "=== 0) Preflight: Processor health and topics exist ==="
	@$(call SSH,$(VM3_HOST)) 'curl -sf http://localhost:8080/health && echo "Processor healthy ✅"'
	@$(call SSH,$(VM1_HOST)) 'docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list | egrep -E "gpu\.metrics\.v1|token\.usage\.v1"'

	@echo "=== 0b) Enforce Mongo cap before run (default MAX_DOCS=100) ==="
	@$(call SSH,$(VM2_HOST)) 'DB=ca2; MAX=$${MAX_DOCS:-100}; \
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
	@$(call SSH,$(VM2_HOST)) 'docker exec -i mongodb mongosh --quiet --eval "db.getSiblingDB(\"ca2\").gpu_metrics.countDocuments()" > /tmp/gpu_before.txt'
	@$(call SSH,$(VM2_HOST)) 'docker exec -i mongodb mongosh --quiet --eval "db.getSiblingDB(\"ca2\").token_usage.countDocuments()" > /tmp/tok_before.txt'
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
	@$(call SSH,$(VM2_HOST)) 'docker exec -i mongodb mongosh --quiet --eval "db.getSiblingDB(\"ca2\").gpu_metrics.countDocuments()" > /tmp/gpu_after.txt'
	@$(call SSH,$(VM2_HOST)) 'docker exec -i mongodb mongosh --quiet --eval "db.getSiblingDB(\"ca2\").token_usage.countDocuments()" > /tmp/tok_after.txt'
	@$(call SSH,$(VM2_HOST)) 'GPU_B=$$(cat /tmp/gpu_before.txt); GPU_A=$$(cat /tmp/gpu_after.txt); \
	  TOK_B=$$(cat /tmp/tok_before.txt); TOK_A=$$(cat /tmp/tok_after.txt); \
	  echo "gpu_metrics(after)=$$GPU_A (before=$$GPU_B)"; echo "token_usage(after)=$$TOK_A (before=$$TOK_B)"; \
	  test $$(($$GPU_A-$$GPU_B)) -ge 1 && echo "gpu_metrics delta OK ✅" || { echo "gpu_metrics did not increase ❌"; exit 1; }; \
	  test $$(($$TOK_A-$$TOK_B)) -ge 1 && echo "token_usage delta OK ✅" || { echo "token_usage did not increase ❌"; exit 1; }'

	@echo "=== 5) Processor API spot-check ==="
	@$(call SSH,$(VM3_HOST)) 'curl -sf http://localhost:8080/gpu/info | sed -e "s/.*/sample: &/;q" || true'

	@echo "=== ✅ Workflow verified end-to-end ==="

# --- Tunables ---
NS_PLATFORM ?= platform
NS_APP      ?= app
DB_NAME     ?= ca2
WAIT_SEC    ?= 5
MAX_DOCS    ?= 1000
TOPIC_REGEX ?= '^(gpu\.metrics\.v1|token\.usage\.v1)$$'

# --- Helpers ---
define FIRST_POD
$$(KUBECONFIG=$(KUBECONFIGL) kubectl -n $(1) get pod -l $(2) -o jsonpath='{.items[0].metadata.name}')
endef

.PHONY: verify-workflow
verify-workflow: verify-preflight verify-mongo-cap verify-deltas verify-processor-api
	@echo "=== ✅ Workflow verified end-to-end ==="

# --- Preflight: readiness + topics ---
verify-preflight:
	@echo "=== Preflight: Kafka, Mongo, Processor ready ==="
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n $(NS_PLATFORM) rollout status sts/kafka  --timeout=180s
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n $(NS_PLATFORM) rollout status sts/mongo  --timeout=180s
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n $(NS_APP)      rollout status deploy/processor --timeout=120s
	@echo "=== Kafka topics (auto-created after publish) ==="
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n $(NS_PLATFORM) exec -i $(call FIRST_POD,$(NS_PLATFORM),app=kafka) -- \
	  kafka-topics --bootstrap-server kafka.$(NS_PLATFORM).svc.cluster.local:9092 --list 2>/dev/null | egrep -E $(TOPIC_REGEX) || \
	  echo "(No topics yet—will be auto-created on first publish)"

# --- Mongo cap enforcement (like CA1/CA0 flow) ---
verify-mongo-cap:
	@echo "=== Enforce Mongo cap (MAX_DOCS=$(MAX_DOCS)) ==="
	@if [ "$(MAX_DOCS)" != "0" ]; then \
	  KUBECONFIG=$(KUBECONFIGL) kubectl -n $(NS_PLATFORM) exec -i $(call FIRST_POD,$(NS_PLATFORM),app=mongo) -- \
	    bash -lc 'DB="$(DB_NAME)"; MAX=$(MAX_DOCS); \
	    GM=$$(mongosh --quiet --eval "db.getSiblingDB(\"$$DB\").gpu_metrics.countDocuments()"); \
	    TU=$$(mongosh --quiet --eval "db.getSiblingDB(\"$$DB\").token_usage.countDocuments()"); \
	    GP=$$(mongosh --quiet --eval "db.getSiblingDB(\"$$DB\").gpus.countDocuments() || 0"); \
	    echo "Counts: gpu_metrics=$$GM token_usage=$$TU gpus=$$GP (cap=$$MAX)"; \
	    if [ $$GM -gt $$MAX ] || [ $$TU -gt $$MAX ] || [ $$GP -gt $$MAX ]; then \
	      echo "Cap exceeded → dropping collections gpu_metrics, token_usage, gpus"; \
	      mongosh --quiet --eval "const d=db.getSiblingDB(\"$$DB\"); d.gpu_metrics.drop(); d.token_usage.drop(); d.gpus.drop(); print(\"dropped\")"; \
	      sleep 2; \
	    else echo "Counts within cap → no reset"; fi'; \
	fi

# --- Baseline → nudge Producers → verify deltas ---
verify-deltas:
	@echo "=== 1) Baseline Mongo counts (before) ==="
	@GPU_B=$$(KUBECONFIG=$(KUBECONFIGL) kubectl -n $(NS_PLATFORM) exec -i $(call FIRST_POD,$(NS_PLATFORM),app=mongo) -- \
	  mongosh --quiet --eval 'db.getSiblingDB("$(DB_NAME)").gpu_metrics.countDocuments()'); \
	TOK_B=$$(KUBECONFIG=$(KUBECONFIGL) kubectl -n $(NS_PLATFORM) exec -i $(call FIRST_POD,$(NS_PLATFORM),app=mongo) -- \
	  mongosh --quiet --eval 'db.getSiblingDB("$(DB_NAME)").token_usage.countDocuments()'); \
	echo "gpu_metrics(before)=$$GPU_B"; echo "token_usage(before)=$$TOK_B"; \
	echo "=== 2) Restart Producers (nudge) ==="; \
	KUBECONFIG=$(KUBECONFIGL) kubectl -n $(NS_APP) rollout restart deploy/producers >/dev/null; \
	KUBECONFIG=$(KUBECONFIGL) kubectl -n $(NS_APP) rollout status deploy/producers --timeout=120s; \
	echo "=== 3) Wait $(WAIT_SEC)s for Processor to consume ==="; sleep $(WAIT_SEC); \
	echo "=== 4) Mongo counts (after) + assertions ==="; \
	GPU_A=$$(KUBECONFIG=$(KUBECONFIGL) kubectl -n $(NS_PLATFORM) exec -i $(call FIRST_POD,$(NS_PLATFORM),app=mongo) -- \
	  mongosh --quiet --eval 'db.getSiblingDB("$(DB_NAME)").gpu_metrics.countDocuments()'); \
	TOK_A=$$(KUBECONFIG=$(KUBECONFIGL) kubectl -n $(NS_PLATFORM) exec -i $(call FIRST_POD,$(NS_PLATFORM),app=mongo) -- \
	  mongosh --quiet --eval 'db.getSiblingDB("$(DB_NAME)").token_usage.countDocuments()'); \
	echo "gpu_metrics(after)=$$GPU_A (before=$$GPU_B)"; echo "token_usage(after)=$$TOK_A (before=$$TOK_B)"; \
	test $$(($$GPU_A-$$GPU_B)) -ge 1 && echo "gpu_metrics delta OK ✅" || { echo "gpu_metrics did not increase ❌"; exit 1; }; \
	test $$(($$TOK_A-$$TOK_B)) -ge 1 && echo "token_usage delta OK ✅" || { echo "token_usage did not increase ❌"; exit 1; }

# --- Processor API spot-check ---
verify-processor-api:
	@echo "=== Processor API spot-check ==="
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n $(NS_APP) port-forward deploy/processor 8080:8080 >/dev/null 2>&1 & PF=$$!; \
	sleep 1; \
	curl -sf http://localhost:8080/health >/dev/null && echo "health: OK"; \
	( curl -sf http://localhost:8080/gpu/info | sed -e "s/.*/sample: &/;q" ) || true; \
	kill $$PF >/dev/null 2>&1 || true

# ===== HPA autoscale validation (requires metrics-server) =====
HPA_NAME ?= producers
BURST_RATE ?= 500     # temporary high load to trigger CPU > target
COOLDOWN_SEC ?= 60     # time to let HPA cool down after removing the override
HPA_TIMEOUT_SEC ?= 300 # total time budget to observe scale events

.PHONY: verify-scale-hpa
verify-scale-hpa:
	@echo "=== Check HPA and metrics availability ==="
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n app get hpa $(HPA_NAME) || { echo "No HPA $(HPA_NAME) ❌"; exit 1; }
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n kube-system get deploy metrics-server >/dev/null 2>&1 && \
	  echo "metrics-server present ✅" || echo "ℹ metrics-server not found; autoscale may not react"

	@echo "=== Snapshot current replicas & desired ==="
	@CUR=$$(KUBECONFIG=$(KUBECONFIGL) kubectl -n app get deploy/producers -o jsonpath='{.status.replicas}'); \
	DES=$$(KUBECONFIG=$(KUBECONFIGL) kubectl -n app get hpa $(HPA_NAME) -o jsonpath='{.status.desiredReplicas}'); \
	echo "current=$$CUR desired=$$DES"

	@echo "=== Trigger load: temporarily override RATE=$(BURST_RATE) ==="
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n app set env deploy/producers RATE=$(BURST_RATE) --containers=producers --overwrite
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n app rollout status deploy/producers --timeout=120s

	@echo "=== Wait for HPA to scale UP (timeout $(HPA_TIMEOUT_SEC)s) ==="
	@START=$$(date +%s); \
	while true; do \
	  CUR=$$(KUBECONFIG=$(KUBECONFIGL) kubectl -n app get deploy/producers -o jsonpath='{.status.replicas}'); \
	  DES=$$(KUBECONFIG=$(KUBECONFIGL) kubectl -n app get hpa $(HPA_NAME) -o jsonpath='{.status.desiredReplicas}'); \
	  echo "now: replicas=$$CUR desired=$$DES"; \
	  if [ "$$DES" != "" ] && [ "$$DES" -ge 2 ]; then echo "Scaled up (desired=$$DES) ✅"; break; fi; \
	  NOW=$$(date +%s); ELAPSED=$$((NOW-START)); \
	  [ "$$ELAPSED" -gt "$(HPA_TIMEOUT_SEC)" ] && { echo "Timed out waiting for scale up ❌"; exit 1; } || sleep 10; \
	done

	@echo "=== Remove override (restore ConfigMap value): RATE- ==="
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n app set env deploy/producers RATE- --containers=producers
	@KUBECONFIG=$(KUBECONFIGL) kubectl -n app rollout status deploy/producers --timeout=120s
	@echo "Cooling down $(COOLDOWN_SEC)s to let metrics drop..."
	@sleep $(COOLDOWN_SEC)

	@echo "=== Wait for HPA to scale DOWN (timeout $(HPA_TIMEOUT_SEC)s) ==="
	@START=$$(date +%s); \
	while true; do \
	  CUR=$$(KUBECONFIG=$(KUBECONFIGL) kubectl -n app get deploy/producers -o jsonpath='{.status.replicas}'); \
	  DES=$$(KUBECONFIG=$(KUBECONFIGL) kubectl -n app get hpa $(HPA_NAME) -o jsonpath='{.status.desiredReplicas}'); \
	  echo "now: replicas=$$CUR desired=$$DES"; \
	  if [ "$$DES" != "" ] && [ "$$DES" -le 1 ]; then echo "Scaled down (desired=$$DES) ✅"; break; fi; \
	  NOW=$$(date +%s); ELAPSED=$$((NOW-START)); \
	  [ "$$ELAPSED" -gt "$(HPA_TIMEOUT_SEC)" ] && { echo "Timed out waiting for scale down ❌"; exit 1; } || sleep 10; \
	done

ssh-kafka: ensure-tf    ; @ssh $(SSH_OPTS) $(SSH_USER)@$(VM1_PUB)
ssh-mongo: ensure-tf    ; @ssh $(SSH_OPTS) $(SSH_USER)@$(VM2_PUB)
ssh-processor: ensure-tf ; @ssh $(SSH_OPTS) $(SSH_USER)@$(VM3_PUB)
ssh-producers: ensure-tf ; @ssh $(SSH_OPTS) $(SSH_USER)@$(VM4_PUB)
ssh-control-plane: ensure-tf
	@echo "Connecting to CONTROL PLANE: $(CP_PUB)"
	@ssh $(SSH_OPTS) $(SSH_USER)@$(CP_PUB)

ssh-worker1: ensure-tf put-key
	@[ -n "$(W1_PRIV)" ] || (echo "Worker #1 private IP missing"; exit 1)
	@echo "Connecting to WORKER 1 (via control-plane, ProxyJump) ..."
	@ssh -tt $(SSH_OPTS) -J $(SSH_USER)@$(CP_PUB) $(SSH_USER)@$(W1_PRIV) < /dev/tty

ssh-worker2: ensure-tf put-key
	@echo "Connecting to WORKER 2 (via control-plane) ..."
	@ssh $(SSH_OPTS) $(SSH_USER)@$(CP_PUB) ssh $(SSH_USER)@$(W2_PRIV)


bootstrap-k3s:
	@echo "🚀 Bootstrapping K3s on control plane..."
	@ssh -tt -i ~/.ssh/ca0 -o StrictHostKeyChecking=no ubuntu@$(CP_PUB) '\
		set -euo pipefail; \
		echo "[INFO] Installing K3s (server)..."; \
		PUB_IP=$$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo ""); \
		PRIV_IP=$$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 || echo ""); \
		curl -sfL https://get.k3s.io | \
		  INSTALL_K3S_EXEC="server --write-kubeconfig-mode=644 --tls-san $$PUB_IP --tls-san $$PRIV_IP" \
		  sh -; \
		echo "[INFO] Waiting for kubeconfig..."; \
		for i in $$(seq 1 30); do [ -f /etc/rancher/k3s/k3s.yaml ] && break || sleep 3; done; \
		cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/kubeconfig-external.yaml; \
		chown ubuntu:ubuntu /home/ubuntu/kubeconfig-external.yaml; \
		if [ -n "$$PUB_IP" ]; then \
		  sed -i "s|server: https://.*:6443|server: https://$$PUB_IP:6443|g" /home/ubuntu/kubeconfig-external.yaml; \
		fi; \
		echo "[INFO] K3s installed and kubeconfig exported."; \
		exit 0'

	@echo "📥 Pulling kubeconfig to local machine..."
	@mkdir -p .kube
	@scp -i ~/.ssh/ca0 ubuntu@$(CP_PUB):/home/ubuntu/kubeconfig-external.yaml .kube/kubeconfig.yaml
	@echo "✅ Done! You can now run:"
	@echo "   KUBECONFIG=.kube/kubeconfig.yaml kubectl get nodes -o wide"


# ---------- Kubeconfig pull ----------
kubeconfig: ensure-tf
	@[ -n "$(CP_PUB)" ] || (echo "control_plane_public_ip missing. Run terraform apply first." && exit 1)
	@[ -n "$(REMOTE_KUBECONFIG)" ] || (echo "remote_kubeconfig_path missing. Check your module output." && exit 1)
	@mkdir -p .kube
	@echo "Pulling kubeconfig from $(CP_PUB):$(REMOTE_KUBECONFIG)..."
	@scp $(SSH_OPTS) $(SSH_USER)@$(CP_PUB):$(REMOTE_KUBECONFIG) .kube/kubeconfig.yaml
	@echo "✅ Saved to .kube/kubeconfig.yaml"

# ---------- Convenience ----------
kubectl-test: ensure-kubeconfig
	@KUBECONFIG=$(KUBECONFIGL) kubectl get nodes -o wide

status: ensure-kubeconfig
	@KUBECONFIG=$(KUBECONFIGL) kubectl get nodes -o wide
	@echo "----"
	@KUBECONFIG=$(KUBECONFIGL) kubectl get pods -A -o wide

clean-kubeconfig:
	@rm -f $(KUBECONFIGL)
	@echo "🧹 Removed $(KUBECONFIGL)"

# -------- Worker join helpers --------

# Fetch the K3s server token from the control-plane
get-token:
	@[ -n "$(CP_PUB)" ] || (echo "control_plane_public_ip missing. Run terraform apply."; exit 1)
	@echo "🔑 Fetching K3s server token from control-plane..."
	@ssh $(SSH_OPTS) $(SSH_USER)@$(CP_PUB) 'sudo cat /var/lib/rancher/k3s/server/node-token' > .k3s_token
	@chmod 600 .k3s_token
	@echo "Saved token to .k3s_token"

# Join a specific worker via control-plane jump
join-worker-1: get-token
	@[ -n "$(W1_PRIV)" ] || (echo "worker #1 private IP missing from TF outputs"; exit 1)
	@echo "🤝 Joining worker-1 ($(W1_PRIV)) to control-plane..."
	@ssh $(SSH_OPTS) $(SSH_USER)@$(CP_PUB) "\
	  set -euo pipefail; \
	  TOKEN=\$$(cat /home/ubuntu/.k3s_token 2>/dev/null || true); \
	  if [ -z \"\$$TOKEN\" ]; then sudo cat /var/lib/rancher/k3s/server/node-token > /home/ubuntu/.k3s_token; TOKEN=\$$(cat /home/ubuntu/.k3s_token); fi; \
	  SERVER_PRIV=\$$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4); \
	  echo 'Using SERVER_PRIV='\"\$$SERVER_PRIV\"; \
	  ssh -o StrictHostKeyChecking=no $(SSH_USER)@$(W1_PRIV) '\
	    curl -sfL https://get.k3s.io | \
	      K3S_URL=https://'\$$SERVER_PRIV':6443 \
	      K3S_TOKEN='\$$TOKEN' \
	      INSTALL_K3S_EXEC=\"agent --node-name worker-1\" \
	      sh -s - agent \
	  '; \
	  echo 'worker-1 joined' \
	"

join-worker-2: get-token
	@[ -n "$(W2_PRIV)" ] || (echo "worker #2 private IP missing from TF outputs"; exit 1)
	@echo "🤝 Joining worker-2 ($(W2_PRIV)) to control-plane..."
	@ssh $(SSH_OPTS) $(SSH_USER)@$(CP_PUB) "\
	  set -euo pipefail; \
	  TOKEN=\$$(cat /home/ubuntu/.k3s_token 2>/dev/null || true); \
	  if [ -z \"\$$TOKEN\" ]; then sudo cat /var/lib/rancher/k3s/server/node-token > /home/ubuntu/.k3s_token; TOKEN=\$$(cat /home/ubuntu/.k3s_token); fi; \
	  SERVER_PRIV=\$$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4); \
	  echo 'Using SERVER_PRIV='\"\$$SERVER_PRIV\"; \
	  ssh -o StrictHostKeyChecking=no $(SSH_USER)@$(W2_PRIV) '\
	    curl -sfL https://get.k3s.io | \
	      K3S_URL=https://'\$$SERVER_PRIV':6443 \
	      K3S_TOKEN='\$$TOKEN' \
	      INSTALL_K3S_EXEC=\"agent --node-name worker-2\" \
	      sh -s - agent \
	  '; \
	  echo 'worker-2 joined' \
	"

join-workers: join-worker-1 join-worker-2
	@echo "✅ Workers joined. Run: make status"

tunnel:
	@[ -n "$(CP_PUB)" ] || (echo "No control_plane_public_ip; run terraform apply." && exit 1)
	@echo "Forwarding localhost:6443 -> control-plane:6443 (Ctrl-C to close)"
	@ssh -i $(SSH_KEY) -N -L 6443:127.0.0.1:6443 $(SSH_USER)@$(CP_PUB)


.PHONY: deploy undeploy namespaces

namespaces: ensure-kubeconfig
	@KUBECONFIG=$(KUBECONFIGL) kubectl $(KUBECTL_OPTS) create ns platform --dry-run=client -o yaml | \
	  KUBECONFIG=$(KUBECONFIGL) kubectl $(KUBECTL_OPTS) apply -f -
	@KUBECONFIG=$(KUBECONFIGL) kubectl $(KUBECTL_OPTS) create ns app --dry-run=client -o yaml | \
	  KUBECONFIG=$(KUBECONFIGL) kubectl $(KUBECTL_OPTS) apply -f -

deploy: ensure-kubeconfig namespaces
	@echo "🚀 Deploying all Kubernetes manifests..."
	@KUBECONFIG=$(KUBECONFIGL) kubectl $(KUBECTL_OPTS) apply -R -f $(K8S_DIR)
	@echo "✅ All manifests applied."

undeploy: ensure-kubeconfig
	@echo "🧹 Deleting all Kubernetes resources..."
	@KUBECONFIG=$(KUBECONFIGL) kubectl delete -R -f $(K8S_DIR) || true
	@echo "✅ All manifests deleted."

# ------------------------------
# Simple smoke: ensure topics exist then list (idempotent)
# ------------------------------
smoke:
	@if [ -z "$(VM1_PUB)" ]; then echo "VM1 public IP missing; cannot SSH. See 'make addrs'."; exit 1; fi
	@echo ">> Creating topics if not exists on VM1 then listing"
	@$(call SSH,$(VM1_HOST)) '\
	  docker exec kafka kafka-topics.sh --create --if-not-exists --topic gpu.metrics.v1   --bootstrap-server localhost:9092; \
	  docker exec kafka kafka-topics.sh --create --if-not-exists --topic token.usage.v1  --bootstrap-server localhost:9092; \
	  docker exec kafka kafka-topics.sh --list --bootstrap-server localhost:9092 \
	'
