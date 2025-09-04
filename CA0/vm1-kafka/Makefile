KAFKA_BIN=/opt/bitnami/kafka/bin
BROKER=10.0.1.10:9092

.PHONY: up down ps logs topics list-topics
up:            ## Start Kafka
	docker compose up -d
down:          ## Stop Kafka
	docker compose down
ps:
	docker compose ps
logs:
	docker compose logs -f kafka

topics:        ## Create required topics
	docker compose exec -T kafka $(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BROKER) --create --topic gpu.metrics.v1   --partitions 1 --replication-factor 1 || true
	docker compose exec -T kafka $(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BROKER) --create --topic token.usage.v1    --partitions 1 --replication-factor 1 || true

list-topics:
	docker compose exec -T kafka $(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BROKER) --list
