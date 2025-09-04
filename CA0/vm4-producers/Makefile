.PHONY: build up run-once logs
build:        ## Build producer image locally on VM4
	docker compose build
up:           ## Start producer (runs to completion)
	docker compose up --abort-on-container-exit
run-once:     ## Convenience alias
	$(MAKE) up
logs:
	docker compose logs -f producer
