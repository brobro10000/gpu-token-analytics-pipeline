# ===== Remote control from laptop -> VMs over SSH =====
RSYNC_EXCLUDES := \
  --exclude '.git/' \
  --exclude 'node_modules/' \
  --exclude '**/__pycache__/' \
  --exclude '**/*.log' \
  --exclude 'CA0/vm1-kafka/data/**' \
  --exclude 'CA0/vm2-mongo/mongo-data/**' \
  --exclude 'CA0/**/data/**' \
  --exclude 'CA0/**/mongo-data/**'

# --- Who/where ---
SSH_KEY          ?= ~/.ssh/ca0
SSH_USER         ?= ubuntu
REMOTE_ROOT_DIR  ?= ~/gpu-token-analytics-pipeline
REMOTE_CA0_DIR   ?= $(REMOTE_ROOT_DIR)

# PUBLIC IPs (for SSH)  (strip trailing spaces)
VM1_PUB ?= 3.222.207.91
VM2_PUB ?= 3.239.231.78
VM3_PUB ?= 34.200.237.224
VM4_PUB ?= 44.201.61.111

# PRIVATE IPs
VM1_PRIV ?= 10.0.1.197
VM2_PRIV ?= 10.0.1.86
VM3_PRIV ?= 10.0.1.112
VM4_PRIV ?= 10.0.1.85

# Normalize/strip everything
SSH_USER := $(strip $(SSH_USER))
VM1_PUB  := $(strip $(VM1_PUB))
VM2_PUB  := $(strip $(VM2_PUB))
VM3_PUB  := $(strip $(VM3_PUB))
VM4_PUB  := $(strip $(VM4_PUB))

VM1_HOST := $(SSH_USER)@$(VM1_PUB)
VM2_HOST := $(SSH_USER)@$(VM2_PUB)
VM3_HOST := $(SSH_USER)@$(VM3_PUB)
VM4_HOST := $(SSH_USER)@$(VM4_PUB)

SSH_OPTS := -i $(SSH_KEY) -o StrictHostKeyChecking=accept-new


# ---- Helpers ----
# $(call ssh-run,<user@host>,<command string>)
define ssh-run
	@if [ -z "$(1)" ]; then echo "ERROR: ssh-run got empty host"; exit 2; fi; \
	ssh $(SSH_OPTS) $(1) "bash -lc 'set -euo pipefail; $(2)'"
endef

# $(call rsync-repo,<user@host>)
define rsync-repo
	@if [ -z "$(1)" ]; then echo "ERROR: rsync-repo got empty host"; exit 2; fi; \
	echo "→ rsync to: $(1):$(REMOTE_ROOT_DIR)/"; \
	rsync -az --delete $(RSYNC_EXCLUDES) -e "ssh $(SSH_OPTS)" ./ $(1):$(REMOTE_ROOT_DIR)/
endef

.PHONY: vm1-bootstrap vm2-bootstrap vm3-bootstrap vm4-bootstrap \
        vm1-sync vm2-sync vm3-sync vm4-sync \
        vm1-setup vm1-up vm1-logs vm1-down \
        vm2-setup vm2-up vm2-stats \
        vm3-setup vm3-up vm3-health \
        vm4-setup vm4-run \
        ssh-kafka ssh-mongo ssh-processor ssh-producers \
        ca0-bootstrap ca0-setup ca0-up

.PHONY: debug-vars
debug-vars:
	@echo "SSH_USER=$(SSH_USER)"
	@echo "VM1_PUB=$(VM1_PUB)"
	@echo "VM1_HOST=$(VM1_HOST)"
	@echo "REMOTE_ROOT_DIR=$(REMOTE_ROOT_DIR)"

# ---- Bootstrap: prepare a brand-new Ubuntu VM (one-time-ish) ----
# Installs git/make/python/java, ensures folders exist, and syncs repo.

vm1-bootstrap:
	$(call ssh-run,$(VM1_HOST), \
		sudo apt-get update -y && \
		DEBIAN_FRONTEND=noninteractive sudo apt-get install -yq \
		  git make python3 python3-venv openjdk-17-jre-headless curl rsync && \
		mkdir -p $(REMOTE_ROOT_DIR) \
	)
	$(call rsync-repo,$(VM1_HOST))

vm2-bootstrap:
	$(call ssh-run,$(VM2_HOST), \
		sudo apt-get update -y && \
		DEBIAN_FRONTEND=noninteractive sudo apt-get install -yq \
		  git make python3 python3-venv curl rsync && \
		mkdir -p $(REMOTE_ROOT_DIR) \
	)
	$(call rsync-repo,$(VM2_HOST))

vm3-bootstrap:
	$(call ssh-run,$(VM3_HOST), \
		sudo apt-get update -y && \
		DEBIAN_FRONTEND=noninteractive sudo apt-get install -yq \
		  git make python3 python3-venv curl rsync && \
		mkdir -p $(REMOTE_ROOT_DIR) \
	)
	$(call rsync-repo,$(VM3_HOST))

vm4-bootstrap:
	$(call ssh-run,$(VM4_HOST), \
		sudo apt-get update -y && \
		DEBIAN_FRONTEND=noninteractive sudo apt-get install -yq \
		  git make python3 python3-venv curl rsync && \
		mkdir -p $(REMOTE_ROOT_DIR) \
	)
	$(call rsync-repo,$(VM4_HOST))

# ---- Keep repo in sync on each VM ----
vm1-sync: ; $(call rsync-repo,$(VM1_HOST))
vm2-sync: ; $(call rsync-repo,$(VM2_HOST))
vm3-sync: ; $(call rsync-repo,$(VM3_HOST))
vm4-sync: ; $(call rsync-repo,$(VM4_HOST))

# ---- Run per-VM Make targets remotely (these live in CA0/vm*-*/Makefile) ----
# Kafka VM (VM1)
vm1-setup: vm1-sync
	$(call ssh-run,$(VM1_HOST), \
		cd $(REMOTE_CA0_DIR)/vm1-kafka && \
		make setup KAFKA_BIND_ADDR=$(VM1_PRIV) \
	)


vm1-up:
	$(call ssh-run,$(VM1_HOST), \
		cd $(REMOTE_CA0_DIR)/vm1-kafka && make up \
	)

vm1-logs:
	$(call ssh-run,$(VM1_HOST), \
		cd $(REMOTE_CA0_DIR)/vm1-kafka && make logs \
	)

vm1-down:
	$(call ssh-run,$(VM1_HOST), \
		cd $(REMOTE_CA0_DIR)/vm1-kafka && make down \
	)

# ---- VM2: Mongo ----
vm2-setup: vm2-sync
	$(call ssh-run,$(VM2_HOST), \
		cd $(REMOTE_CA0_DIR)/vm2-mongo && make setup \
	)

vm2-up:
	$(call ssh-run,$(VM2_HOST), \
		cd $(REMOTE_CA0_DIR)/vm2-mongo && make up \
	)

vm2-wait:
	$(call ssh-run,$(VM2_HOST), \
		cd $(REMOTE_CA0_DIR)/vm2-mongo && make wait \
	)

vm2-logs:
	$(call ssh-run,$(VM2_HOST), \
		cd $(REMOTE_CA0_DIR)/vm2-mongo && make logs \
	)

vm2-stats:
	$(call ssh-run,$(VM2_HOST), \
		cd $(REMOTE_CA0_DIR)/vm2-mongo && make stats \
	)

vm2-ping:
	$(call ssh-run,$(VM2_HOST), \
		cd $(REMOTE_CA0_DIR)/vm2-mongo && make ping \
	)

vm2-shell:
	$(call ssh-run,$(VM2_HOST), \
		cd $(REMOTE_CA0_DIR)/vm2-mongo && make shell \
	)

# Processor VM (VM3)
vm3-setup: vm3-sync
	$(call ssh-run,$(VM3_HOST), \
		cd $(REMOTE_CA0_DIR)/vm3-processor && \
		make build \
	)

vm3-build:
	$(call ssh-run,$(VM3_HOST), \
		cd $(REMOTE_CA0_DIR)/vm3-processor && make build \
	)

vm3-up:
	$(call ssh-run,$(VM3_HOST), \
		cd $(REMOTE_CA0_DIR)/vm3-processor && make up \
	)

vm3-wait:
	$(call ssh-run,$(VM3_HOST), \
		cd $(REMOTE_CA0_DIR)/vm3-processor && make wait \
	)

# Follow processor logs
vm3-logs:
	$(call ssh-run,$(VM3_HOST), \
		cd $(REMOTE_CA0_DIR)/vm3-processor && make logs \
	)

# Query health endpoint directly (bypasses Makefile inside VM3)
vm3-health:
	$(call ssh-run,$(VM3_HOST), \
		curl -sS http://localhost:8080/health || true \
	)

vm3-down:
	$(call ssh-run,$(VM3_HOST), \
		cd $(REMOTE_CA0_DIR)/vm3-processor && make down \
	)

vm3-restart:
	$(call ssh-run,$(VM3_HOST), \
		cd $(REMOTE_CA0_DIR)/vm3-processor && make restart \
	)

# Producers VM (VM4)
vm4-setup: vm4-sync
	$(call ssh-run,$(VM4_HOST), \
		cd $(REMOTE_CA0_DIR)/vm4-producers && \
		make setup KAFKA_BOOTSTRAP=$(VM1_PRIV):9092 \
	)

vm4-run:
	$(call ssh-run,$(VM4_HOST), \
		cd $(REMOTE_CA0_DIR)/vm4-producers && make run \
	)

# ---- Convenience SSH targets ----
ssh-kafka:     ; @ssh $(SSH_OPTS) $(SSH_USER)@$(VM1_PUB)
ssh-mongo:     ; @ssh $(SSH_OPTS) $(SSH_USER)@$(VM2_PUB)
ssh-processor: ; @ssh $(SSH_OPTS) $(SSH_USER)@$(VM3_PUB)
ssh-producers: ; @ssh $(SSH_OPTS) $(SSH_USER)@$(VM4_PUB)

# ---- One-shot pipeline bring-up (from your laptop) ----
ca0-bootstrap: vm1-bootstrap vm2-bootstrap vm3-bootstrap vm4-bootstrap
ca0-setup:     vm1-setup vm2-setup vm3-setup vm4-setup
ca0-up:        vm1-up vm3-up vm4-run
