.PHONY: build up down ps logs health
build:          ## Build processor image locally on VM3
	docker compose build
up:             ## Start processor
	docker compose up -d
down:
	docker compose down
ps:
	docker compose ps
logs:
	docker compose logs -f processor
health:         ## Check HTTP health
	curl -sS http://localhost:8080/health | jq .
