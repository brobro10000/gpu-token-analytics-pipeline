# ===== VM1: Kafka (Bitnami, single-node KRaft) =====
SHELL := /bin/bash
.ONESHELL:                   # run each recipe in a single shell

# ---- Config (override from root via: make vm1-up KAFKA_BIND_ADDR=10.0.1.197) ----
COMPOSE         ?= docker compose
KAFKA_BIND_ADDR ?= 10.0.1.197          # VM1 private IP
BROKER          ?= $(KAFKA_BIND_ADDR):9092
KAFKA_BIN       ?= /opt/bitnami/kafka/bin

TOPIC_METRIC ?= gpu.metrics.v1
TOPIC_TOKEN  ?= token.usage.v1

.PHONY: help setup up down restart ps logs health topics list-topics \
        send-metric send-token consume-metric consume-token wipe

help:
	@echo "Targets:"
	@echo "  setup           Install Docker/Compose if missing; create data dir"
	@echo "  up / down       Start/stop kafka (compose)"
	@echo "  restart         Down + up"
	@echo "  ps / logs       Container status / follow logs"
	@echo "  health          Print container health (healthy/starting/…)"
	@echo "  topics          Create required topics (idempotent)"
	@echo "  list-topics     List topics"
	@echo "  send-metric     Produce one sample GPU metric"
	@echo "  send-token      Produce one sample token-usage event"
	@echo "  consume-*       Console consumers (Ctrl+C to stop)"
	@echo "  wipe            Compose down -v (remove volumes)"
	@echo
	@echo "Vars:"
	@echo "  KAFKA_BIND_ADDR=$(KAFKA_BIND_ADDR)"
	@echo "  BROKER=$(BROKER)"

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
	mkdir -p ./data

up:
	KAFKA_BIND_ADDR=$(KAFKA_BIND_ADDR) $(COMPOSE) up -d
	$(COMPOSE) ps

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) down
	KAFKA_BIND_ADDR=$(KAFKA_BIND_ADDR) $(COMPOSE) up -d

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f --tail=200 kafka

health:
	STATUS=$$(docker inspect --format '{{.State.Health.Status}}' kafka 2>/dev/null || echo "unknown")
	echo "kafka container health: $$STATUS"

# ---- Topics ----
topics:
	$(COMPOSE) exec -T kafka $(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BROKER) --create --topic $(TOPIC_METRIC) --partitions 1 --replication-factor 1 || true
	$(COMPOSE) exec -T kafka $(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BROKER) --create --topic $(TOPIC_TOKEN)  --partitions 1 --replication-factor 1 || true
	$(MAKE) list-topics

list-topics:
	$(COMPOSE) exec -T kafka $(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BROKER) --list

# ---- One-shot producers ----
send-metric:
	@echo "Sending one event to $(TOPIC_METRIC) via $(BROKER) ..."
	$(COMPOSE) exec -T kafka bash -lc '\
	  printf "%s\n" "{\"ts\":\"$$(date -u +%FT%TZ)\",\"gpu_index\":0,\"utilization\":0.72,\"mem_used_mb\":11000,\"mem_total_mb\":24576,\"power_w\":250}" \
	  | $(KAFKA_BIN)/kafka-console-producer.sh --bootstrap-server $(BROKER) --topic $(TOPIC_METRIC)'

send-token:
	@echo "Sending one event to $(TOPIC_TOKEN) via $(BROKER) ..."
	$(COMPOSE) exec -T kafka bash -lc '\
	  printf "%s\n" "{\"ts\":\"$$(date -u +%FT%TZ)\",\"model\":\"llama-3-70b\",\"prompt_tokens\":1285,\"completion_tokens\":391,\"latency_ms\":622,\"gpu_index\":0}" \
	  | $(KAFKA_BIN)/kafka-console-producer.sh --bootstrap-server $(BROKER) --topic $(TOPIC_TOKEN)'

# ---- Quick consumers (Ctrl+C to stop) ----
consume-metric:
	$(COMPOSE) exec -T kafka $(KAFKA_BIN)/kafka-console-consumer.sh --bootstrap-server $(BROKER) --topic $(TOPIC_METRIC) --from-beginning

consume-token:
	$(COMPOSE) exec -T kafka $(KAFKA_BIN)/kafka-console-consumer.sh --bootstrap-server $(BROKER) --topic $(TOPIC_TOKEN) --from-beginning

# ---- Nuke local volumes (data) ----
wipe:
	$(COMPOSE) down -v
