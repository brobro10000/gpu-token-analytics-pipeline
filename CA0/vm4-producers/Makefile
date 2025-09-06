.SHELLFLAGS := -eu -o pipefail -c
.PHONY: help setup build up run-once logs ps down restart doctor

SHELL := /bin/bash
.ONESHELL:
DOCKER  := $(shell if docker info >/dev/null 2>&1; then echo docker; else echo "sudo docker"; fi)
COMPOSE := $(DOCKER) compose

KAFKA ?= $(shell (grep -E '^KAFKA_BOOTSTRAP=' .env || echo KAFKA_BOOTSTRAP=10.0.1.197:9092) | cut -d= -f2)

help:
	@echo "Targets: setup | build | up | run-once | logs | ps | down | restart | doctor"

setup:  ## Install Docker/Compose if missing + build
	if ! command -v docker >/dev/null 2>&1; then \
	  sudo apt-get remove -y docker docker-engine docker.io containerd runc || true; \
	  sudo apt-get update -y; \
	  sudo apt-get install -y ca-certificates curl gnupg; \
	  sudo install -m 0755 -d /etc/apt/keyrings; \
	  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
	  echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo $$VERSION_CODENAME) stable" \
	    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null; \
	  sudo apt-get update -y; \
	  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; \
	  sudo usermod -aG docker $$USER || true; \
	fi
	$(COMPOSE) build

build:
	$(COMPOSE) build

up:        ## Run producer once (exits when done)
	$(COMPOSE) up --abort-on-container-exit

run-once:  ## Alias
	$(MAKE) up

logs:
	$(COMPOSE) logs -f producer

ps:
	$(COMPOSE) ps

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) down
	$(COMPOSE) up --abort-on-container-exit

doctor:    ## Check Kafka reachability
	@KHOST="$(word 1,$(subst :, ,$(KAFKA)))"; KPORT="$(word 2,$(subst :, ,$(KAFKA)))"; \
	echo "→ Kafka $(KAFKA)"; \
	nc -zv -w 2 $$KHOST $$KPORT >/dev/null 2>&1 && echo "OK" || (echo "FAIL"; exit 1)
