# ===== VM1: Kafka Makefile =====
# Override BROKER if needed: make send-metric BROKER=192.168.1.50:9092

KAFKA_BIN ?= /opt/bitnami/kafka/bin
BROKER    ?= 10.0.1.10:9092

TOPIC_METRIC ?= gpu.metrics.v1
TOPIC_TOKEN  ?= token.usage.v1

.PHONY: help up down ps logs topics list-topics send-metric send-token consume-metric consume-token

help:
	@echo "Targets:"
	@echo "  up / down / ps / logs"
	@echo "  topics         - Create $(TOPIC_METRIC) and $(TOPIC_TOKEN) (idempotent)"
	@echo "  list-topics    - List topics"
	@echo "  send-metric    - Send one JSON event to $(TOPIC_METRIC)"
	@echo "  send-token     - Send one JSON event to $(TOPIC_TOKEN)"
	@echo "  consume-metric - Console-consume $(TOPIC_METRIC) (Ctrl+C to stop)"
	@echo "  consume-token  - Console-consume $(TOPIC_TOKEN) (Ctrl+C to stop)"

up:            ## Start Kafka
	docker compose up -d

down:          ## Stop Kafka
	docker compose down

ps:
	docker compose ps

logs:
	docker compose logs -f kafka

topics:        ## Create required topics (idempotent)
	docker compose exec -T kafka $(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BROKER) --create --topic $(TOPIC_METRIC) --partitions 1 --replication-factor 1 || true
	docker compose exec -T kafka $(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BROKER) --create --topic $(TOPIC_TOKEN)  --partitions 1 --replication-factor 1 || true
	$(MAKE) list-topics

list-topics:
	docker compose exec -T kafka $(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BROKER) --list

# --------- One-shot producers (no heredocs) ---------

send-metric:
	@echo "Sending one event to $(TOPIC_METRIC) ..."
	docker compose exec -T kafka bash -lc '\
	  printf "%s\n" "{\"ts\":\"$$(date -u +%FT%TZ)\",\"gpu_index\":0,\"utilization\":0.72,\"mem_used_mb\":11000,\"mem_total_mb\":24576,\"power_w\":250}" \
	  | $(KAFKA_BIN)/kafka-console-producer.sh --bootstrap-server $(BROKER) --topic $(TOPIC_METRIC)'

send-token:
	@echo "Sending one event to $(TOPIC_TOKEN) ..."
	docker compose exec -T kafka bash -lc '\
	  printf "%s\n" "{\"ts\":\"$$(date -u +%FT%TZ)\",\"model\":\"llama-3-70b\",\"prompt_tokens\":1285,\"completion_tokens\":391,\"latency_ms\":622,\"gpu_index\":0}" \
	  | $(KAFKA_BIN)/kafka-console-producer.sh --bootstrap-server $(BROKER) --topic $(TOPIC_TOKEN)'

# --------- Quick consumers (Ctrl+C to stop) ---------

consume-metric:
	docker compose exec -T kafka $(KAFKA_BIN)/kafka-console-consumer.sh --bootstrap-server $(BROKER) --topic $(TOPIC_METRIC) --from-beginning

consume-token:
	docker compose exec -T kafka $(KAFKA_BIN)/kafka-console-consumer.sh --bootstrap-server $(BROKER) --topic $(TOPIC_TOKEN) --from-beginning
