.PHONY: build up wait down restart ps logs health curl

build:          ## Build processor image locally on VM3
	docker compose build

up:             ## Start processor
	docker compose up -d

wait:           ## Wait for health to be OK
	for i in $$(seq 1 30); do \
	  if curl -sf http://localhost:8080/health >/dev/null; then \
	    echo "processor is healthy"; exit 0; \
	  fi; \
	  sleep 2; \
	done; echo "health timeout" >&2; exit 1

down:           ## Stop (keep data; none is mounted here)
	docker compose down

restart:
	docker compose down
	docker compose up -d

ps:
	docker compose ps

logs:
	docker compose logs -f processor

health:
	curl -sS http://localhost:8080/health | jq .

curl:
	curl -sS http://localhost:8080/gpu/info | jq .
