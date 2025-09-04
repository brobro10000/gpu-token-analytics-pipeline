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
