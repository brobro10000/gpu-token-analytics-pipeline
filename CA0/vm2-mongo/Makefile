# ===== VM2: MongoDB (single node) =====
SHELL := /bin/bash
.ONESHELL:

SERVICE ?= mongo         # matches container_name
DB      ?= ca0
MONGO   ?= mongosh
COMPOSE ?= docker compose

.PHONY: help setup up down down-v restart ps logs wait ping init-indexes stats shell fix-perms

help:
	@echo "Targets:"
	@echo "  setup         - Install Docker/Compose if missing (idempotent)"
	@echo "  up            - Start Mongo (detached)"
	@echo "  wait          - Wait until Mongo responds to ping"
	@echo "  ping          - db.adminCommand('ping')"
	@echo "  init-indexes  - Apply /docker-entrypoint-initdb.d/indexes.js (idempotent)"
	@echo "  stats         - Counts in $(DB).gpu_metrics and $(DB).token_usage"
	@echo "  shell         - Interactive mongosh in the container"
	@echo "  ps / logs     - Status / follow logs"
	@echo "  down / down-v - Stop / stop+remove volumes"
	@echo "  fix-perms     - Chown ./mongo-data to uid 999 (host-dir setups)"

setup:
	if ! command -v docker >/dev/null 2>&1; then
		sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
		sudo apt-get update -y
		sudo apt-get install -y ca-certificates curl gnupg
		sudo install -m 0755 -d /etc/apt/keyrings
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo $$VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
		sudo apt-get update -y
		sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
		sudo usermod -aG docker $$USER || true
	fi

up:
	$(COMPOSE) up -d
	@echo "Mongo starting... try 'make wait' next."

wait:
	@echo "Waiting for Mongo to be ready..."
	for i in $$(seq 1 30); do \
		if $(COMPOSE) exec -T $(SERVICE) $(MONGO) --quiet --eval "db.adminCommand('ping').ok" | grep -q 1; then \
			echo "Mongo is ready."; exit 0; \
		fi; \
		sleep 2; \
	done; \
	echo "Timed out waiting for Mongo." >&2; exit 1

ping:
	$(COMPOSE) exec -T $(SERVICE) $(MONGO) --quiet --eval 'db.adminCommand("ping")'

init-indexes:
	$(COMPOSE) exec -T $(SERVICE) bash -lc 'test -f /docker-entrypoint-initdb.d/indexes.js'
	$(COMPOSE) exec -T $(SERVICE) $(MONGO) --file /docker-entrypoint-initdb.d/indexes.js
	@echo "Indexes applied."

stats:
	@echo "$(DB).gpu_metrics:"
	$(COMPOSE) exec -T $(SERVICE) $(MONGO) --quiet --eval 'db.getSiblingDB("$(DB)").gpu_metrics.countDocuments()'
	@echo "$(DB).token_usage:"
	$(COMPOSE) exec -T $(SERVICE) $(MONGO) --quiet --eval 'db.getSiblingDB("$(DB)").token_usage.countDocuments()'

shell:
	$(COMPOSE) exec $(SERVICE) $(MONGO)

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f $(SERVICE)

down:
	$(COMPOSE) down

down-v:
	$(COMPOSE) down -v

fix-perms:  ## only needed with host-dir data (./mongo-data)
	sudo mkdir -p ./mongo-data
	sudo chown -R 999:999 ./mongo-data
	sudo chmod -R 775 ./mongo-data

restart:
	$(COMPOSE) down
	$(COMPOSE) up -d
