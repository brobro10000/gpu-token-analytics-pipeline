# ===== VM3: Processor (Dockerized) =====
SHELL := /bin/bash
.ONESHELL:

# Compose commands (auto-fallback to sudo docker if current shell isn't in the docker group yet)
DOCKER := $(shell if docker info >/dev/null 2>&1; then echo docker; else echo "sudo docker"; fi)
COMPOSE := $(DOCKER) compose

# Optional: endpoints used by 'doctor' (override if needed)
KAFKA ?= 10.0.1.197:9092
MONGO ?= 10.0.1.86:27017
PORT  ?= 8080

.PHONY: help setup build up wait down restart ps logs health curl doctor

help:
	@echo "Targets:"
	@echo "  setup    - Install Docker/Compose if missing + add user to docker group + build image"
	@echo "  build    - docker compose build"
	@echo "  up       - docker compose up -d"
	@echo "  wait     - wait for /health to return 200"
	@echo "  logs     - follow app logs"
	@echo "  health   - curl /health"
	@echo "  curl     - curl /gpu/info"
	@echo "  ps       - docker compose ps"
	@echo "  restart  - down + up"
	@echo "  down     - docker compose down (no volumes)"
	@echo "  doctor   - quick reachability checks to Kafka/Mongo + local health"

setup:  ## Install Docker & Compose (if absent) and build the image
	# Install Docker + Compose plugin if not present
	if ! command -v docker >/dev/null 2>&1; then \
	  echo "[setup] Installing Docker & Compose..."; \
	  sudo apt-get remove -y docker docker-engine docker.io containerd runc || true; \
	  sudo apt-get update -y; \
	  sudo apt-get install -y ca-certificates curl gnupg; \
	  sudo install -m 0755 -d /etc/apt/keyrings; \
	  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
	  echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo $$VERSION_CODENAME) stable" \
	    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null; \
	  sudo apt-get update -y; \
	  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; \
	fi
	# Add current user to the docker group (takes effect on next login)
	if ! id -nG $$USER | tr ' ' '\n' | grep -qx docker; then \
	  echo "[setup] Adding $$USER to 'docker' group (you may need to re-login later)"; \
	  sudo usermod -aG docker $$USER || true; \
	fi
	# Build the image (works even before re-login because we fall back to 'sudo docker')
	$(COMPOSE) build

build:         ## Build processor image
	$(COMPOSE) build

up:            ## Start processor
	$(COMPOSE) up -d
	$(COMPOSE) ps

wait:          ## Wait until health endpoint responds
	for i in $$(seq 1 30); do \
	  if curl -fsS http://localhost:$(PORT)/health >/dev/null; then \
	    echo "processor is healthy"; exit 0; \
	  fi; \
	  sleep 2; \
	done; echo "health timeout" >&2; exit 1

down:          ## Stop container (keep data; none mounted here)
	$(COMPOSE) down

restart:
	$(COMPOSE) down
	$(COMPOSE) up -d

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f processor

health:
	curl -sS http://localhost:$(PORT)/health || true

curl:
	curl -sS http://localhost:$(PORT)/gpu/info || true

doctor:        ## Quick checks: Kafka, Mongo, health
	@set -e; \
	KHOST="$(word 1,$(subst :, ,$(KAFKA)))"; KPORT="$(word 2,$(subst :, ,$(KAFKA)))"; \
	MHOST="$(word 1,$(subst :, ,$(MONGO)))"; MPORT="$(word 2,$(subst :, ,$(MONGO)))"; \
	echo "→ checking TCP reachability"; \
	nc -zv -w 2 $$KHOST $$KPORT >/dev/null 2>&1; echo "kafka($(KAFKA)): $$?"; \
	nc -zv -w 2 $$MHOST $$MPORT >/dev/null 2>&1; echo "mongo($(MONGO)): $$?"; \
	echo "→ local health"; \
	curl -fsS --max-time 2 http://localhost:$(PORT)/health >/dev/null && echo "health: OK" || echo "health: not ready"
