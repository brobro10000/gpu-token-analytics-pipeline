# ===== VM2: MongoDB Makefile =====
# Usage:
#   make up           # start Mongo
#   make wait         # wait until mongod responds
#   make init-indexes # run indexes.js (idempotent)
#   make stats        # quick counts
#   make down         # stop
#   make down-v       # stop + remove volumes
#   make shell        # open mongosh in the container
#   make logs         # follow logs
#   make help         # show help

SERVICE ?= mongo
DB      ?= ca0
MONGO   ?= mongosh
COMPOSE ?= docker compose

.PHONY: help up wait down down-v ps logs init-indexes stats shell ping

help:
	@echo "Targets:"
	@echo "  up            - Start MongoDB (detached)"
	@echo "  wait          - Wait for Mongo to accept connections"
	@echo "  init-indexes  - (Re)apply indexes from /docker-entrypoint-initdb.d/indexes.js"
	@echo "  stats         - Show document counts in $(DB).gpu_metrics and $(DB).token_usage"
	@echo "  ping          - db.adminCommand('ping') sanity check"
	@echo "  ps            - Show container status"
	@echo "  logs          - Tail MongoDB logs"
	@echo "  shell         - Open an interactive mongosh inside the container"
	@echo "  down          - Stop containers"
	@echo "  down-v        - Stop containers and remove volumes (DANGEROUS: deletes data)"

up: ## Start MongoDB
	$(COMPOSE) up -d
	@echo "Mongo starting... try 'make wait' next."

wait: ## Wait until Mongo responds
	@echo "Waiting for Mongo to be ready..."
	@for i in $$(seq 1 30); do \
		$(COMPOSE) exec -T $(SERVICE) $(MONGO) --quiet --eval "db.adminCommand('ping').ok" >/dev/null 2>&1 && \
		{ echo "Mongo is ready."; exit 0; }; \
		sleep 2; \
	done; \
	echo "Timed out waiting for Mongo." >&2; exit 1

down: ## Stop containers
	$(COMPOSE) down

down-v: ## Stop containers and remove volumes (DANGEROUS)
	$(COMPOSE) down -v

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f $(SERVICE)

init-indexes: ## (Re)apply indexes (idempotent)
	# Ensure the indexes script exists in the container path
	$(COMPOSE) exec -T $(SERVICE) bash -lc 'test -f /docker-entrypoint-initdb.d/indexes.js'
	$(COMPOSE) exec -T $(SERVICE) $(MONGO) --file /docker-entrypoint-initdb.d/indexes.js
	@echo "Indexes applied."

stats: ## Quick check of counts
	$(COMPOSE) exec -T $(SERVICE) $(MONGO) --quiet --eval 'db.getSiblingDB("$(DB)").gpu_metrics.countDocuments()'
	$(COMPOSE) exec -T $(SERVICE) $(MONGO) --quiet --eval 'db.getSiblingDB("$(DB)").token_usage.countDocuments()'

ping: ## db.adminCommand('ping') check
	$(COMPOSE) exec -T $(SERVICE) $(MONGO) --quiet --eval 'db.adminCommand("ping")'

shell: ## Open interactive mongosh in the container
	$(COMPOSE) exec $(SERVICE) $(MONGO)
=======
DB=ca0
MONGO=mongosh

.PHONY: up down ps logs init-indexes stats
up:              ## Start MongoDB
	docker compose up -d
down:
	docker compose down
ps:
	docker compose ps
logs:
	docker compose logs -f mongo

init-indexes:    ## (Re)apply indexes (idempotent)
	docker compose exec -T mongo $(MONGO) --file /docker-entrypoint-initdb.d/indexes.js

stats:           ## Quick check of counts
	docker compose exec -T mongo $(MONGO) --quiet --eval 'db.getSiblingDB("$(DB)").gpu_metrics.countDocuments()'
	docker compose exec -T mongo $(MONGO) --quiet --eval 'db.getSiblingDB("$(DB)").token_usage.countDocuments()'
