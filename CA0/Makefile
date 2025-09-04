# ===== CA0 Root Makefile (Local Dev, No Compose) =====
# Replicates the end-to-end pipeline locally:
#   Kafka (KRaft) -> Topics -> Processor (FastAPI) -> Producer -> Verify in Mongo
# Also includes cleanup & garbage collection targets.
# -----------------------------------------------------

# ----- Versions & Paths -----
KAFKA_VERSION        ?= 3.7.0
KAFKA_SCALA          ?= 2.13
KAFKA_TGZ            ?= kafka_$(KAFKA_SCALA)-$(KAFKA_VERSION).tgz
KAFKA_URL            ?= https://archive.apache.org/dist/kafka/$(KAFKA_VERSION)/$(KAFKA_TGZ)
KAFKA_DIR            ?= $(PWD)/kafka_$(KAFKA_SCALA)-$(KAFKA_VERSION)
KAFKA_BIN            := $(KAFKA_DIR)/bin
KAFKA_SERVER_PROPS   := $(KAFKA_DIR)/config/kraft/server.properties
KAFKA_PID_FILE       := /tmp/kafka-ca0.pid
KAFKA_LOG_FILE       := /tmp/kafka-ca0.log
KAFKA_DATA_DIR      ?= $(PWD)/.kafka-data
KAFKA_SERVER_LOCAL  ?= $(KAFKA_DIR)/config/kraft/server.local.properties


BOOTSTRAP            ?= localhost:9092
MONGO_URL            ?= mongodb://localhost:27017/ca0
PRICE_PER_HOUR_USD   ?= 0.85
UVICORN_PORT         ?= 8080
PYTHON               ?= python3

PROC_DIR             := vm3-processor/app
PROD_DIR             := vm4-producers
PROC_VENV            := $(PROC_DIR)/.venv
PROD_VENV            := $(PROD_DIR)/.venv

# ----- Phony -----
.PHONY: help up down status \
        kafka-download kafka-start kafka-stop kafka-restart kafka-status kafka-clean \
        topics-create topics-delete topics-list \
        processor-venv processor-run processor-kill \
        producer-venv producer-run \
        health mongo-counts \
        clean gc really-gc

# ----- Help -----
help:
	@echo "Targets:"
	@echo "  make up                # Start Kafka, create topics, show instructions to run processor+producer"
	@echo "  make down              # Stop Kafka (local)"
	@echo "  make status            # Kafka + processor health + Mongo counts"
	@echo ""
	@echo "Kafka:"
	@echo "  make kafka-download    # Download & extract Apache Kafka $(KAFKA_VERSION)"
	@echo "  make kafka-start       # Start Kafka (KRaft) in background"
	@echo "  make kafka-stop        # Stop Kafka"
	@echo "  make kafka-restart     # Restart Kafka"
	@echo "  make kafka-status      # Check Kafka PID and last log lines"
	@echo "  make kafka-clean       # Remove PID/log files (safe)"
	@echo ""
	@echo "Topics:"
	@echo "  make topics-create     # Create gpu.metrics.v1 + token.usage.v1"
	@echo "  make topics-delete     # Delete both topics"
	@echo "  make topics-list       # List topics"
	@echo ""
	@echo "Processor / Producer:"
	@echo "  make processor-venv    # Create venv + install deps"
	@echo "  make processor-run     # Run FastAPI processor (Ctrl+C to stop)"
	@echo "  make processor-kill    # Kill uvicorn if backgrounded elsewhere"
	@echo "  make producer-venv     # Create venv + install deps"
	@echo "  make producer-run      # Run producer (sends ~20 msgs)"
	@echo ""
	@echo "Verification:"
	@echo "  make health            # GET /health"
	@echo "  make mongo-counts      # Show counts in Mongo"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean             # Stop Kafka + clear caches/venvs (non-destructive DB)"
	@echo "  make gc                # Remove Kafka tar/dir + venvs + caches (keeps Mongo data)"
	@echo "  make really-gc         # Aggressive: gc + delete __pycache__ & *.pyc across CA0"

# ----- Top-level flows -----
up: kafka-download kafka-start topics-create
	@echo "== Next steps in NEW terminals =="
	@echo "  1) make processor-venv && make processor-run"
	@echo "  2) make producer-venv  && make producer-run"
	@echo "Then verify:"
	@echo "  make mongo-counts && make health"

down: kafka-stop

status: kafka-status health mongo-counts

# ----- Kafka local (KRaft) -----
$(KAFKA_TGZ):
	curl -L -o $(KAFKA_TGZ) $(KAFKA_URL)

$(KAFKA_SERVER_LOCAL): $(KAFKA_SERVER_PROPS)
	@mkdir -p $(KAFKA_DATA_DIR)
	@sed 's|^log.dirs=.*|log.dirs=$(KAFKA_DATA_DIR)|' $(KAFKA_SERVER_PROPS) > $(KAFKA_SERVER_LOCAL)

kafka-download: $(KAFKA_TGZ)
	@echo "Extracting $(KAFKA_TGZ) -> $(KAFKA_DIR)"
	@tar xzf $(KAFKA_TGZ)

kafka-start: $(KAFKA_SERVER_LOCAL)
	@if [ ! -d "$(KAFKA_DIR)" ]; then echo "Kafka not found. Run: make kafka-download"; exit 1; fi
	@if [ ! -f "$(KAFKA_DATA_DIR)/meta.properties" ]; then \
	  echo "Formatting KRaft storage at $(KAFKA_DATA_DIR) ..."; \
	  $(KAFKA_BIN)/kafka-storage.sh format -t $$(uuidgen) -c $(KAFKA_SERVER_LOCAL); \
	fi
	@echo "Starting Kafka in background..."
	@nohup $(KAFKA_BIN)/kafka-server-start.sh $(KAFKA_SERVER_LOCAL) > $(KAFKA_LOG_FILE) 2>&1 & echo $$! > $(KAFKA_PID_FILE)
	@sleep 2
	@echo "Kafka PID: $$(cat $(KAFKA_PID_FILE))  (logs: $(KAFKA_LOG_FILE))"

kafka-stop:
	@if [ -f "$(KAFKA_PID_FILE)" ]; then \
	  echo "Stopping Kafka PID $$(cat $(KAFKA_PID_FILE))"; \
	  kill $$(cat $(KAFKA_PID_FILE)) >/dev/null 2>&1 || true; \
	  rm -f $(KAFKA_PID_FILE); \
	else echo "Kafka not running (no $(KAFKA_PID_FILE))"; fi

kafka-restart: kafka-stop kafka-start

kafka-status:
	@if [ -f "$(KAFKA_PID_FILE)" ]; then echo "Kafka running (PID $$(cat $(KAFKA_PID_FILE)))"; else echo "Kafka not running"; fi
	@if [ -f "$(KAFKA_LOG_FILE)" ]; then echo "--- tail $(KAFKA_LOG_FILE) ---"; tail -n 5 $(KAFKA_LOG_FILE); fi

kafka-clean:
	@rm -f $(KAFKA_PID_FILE) $(KAFKA_LOG_FILE)
	@echo "Kafka PID/log files removed."

.PHONY: kafka-reset
kafka-reset: kafka-stop
	@rm -rf $(KAFKA_DATA_DIR)
	@rm -f  $(KAFKA_PID_FILE) $(KAFKA_LOG_FILE)
	@echo "Kafka data reset. Run 'make kafka-start' to reformat & start."

# ----- Topics -----
topics-create:
	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --create --topic gpu.metrics.v1   --partitions 1 --replication-factor 1 || true
	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --create --topic token.usage.v1    --partitions 1 --replication-factor 1 || true
	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --list

topics-delete:
	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --delete --topic gpu.metrics.v1 || true
	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --delete --topic token.usage.v1 || true
	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --list

topics-list:
	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --list

# ----- Processor (FastAPI) -----
processor-venv:
	cd $(PROC_DIR) && $(PYTHON) -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt

processor-run:
	cd $(PROC_DIR) && \
	. .venv/bin/activate && \
	export KAFKA_BOOTSTRAP=$(BOOTSTRAP) MONGO_URL=$(MONGO_URL) PRICE_PER_HOUR_USD=$(PRICE_PER_HOUR_USD) && \
	echo "Processor on :$(UVICORN_PORT)" && \
	uvicorn main:app --reload --port $(UVICORN_PORT)

# (best-effort kill; only if you've backgrounded uvicorn yourself)
processor-kill:
	-pkill -f "uvicorn main:app" || true

# ----- Producer -----
producer-venv:
	cd $(PROD_DIR) && $(PYTHON) -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt

producer-run:
	cd $(PROD_DIR) && \
	. .venv/bin/activate && \
	export KAFKA_BOOTSTRAP=$(BOOTSTRAP) && \
	$(PYTHON) producer.py

# ----- Verification -----
health:
	@curl -sS http://localhost:$(UVICORN_PORT)/health || echo "Processor not responding"

mongo-counts:
	@mongosh --quiet --eval 'db.getSiblingDB("ca0").gpu_metrics.countDocuments()'
	@mongosh --quiet --eval 'db.getSiblingDB("ca0").token_usage.findOne()'

# ----- Cleanup / Garbage Collection -----
clean: kafka-stop kafka-clean
	@echo "Cleaning Python caches & venvs..."
	@find $(PROC_DIR) -name "__pycache__" -type d -exec rm -rf {} + || true
	@find $(PROD_DIR) -name "__pycache__" -type d -exec rm -rf {} + || true
	@rm -rf $(PROC_VENV) $(PROD_VENV)
	@echo "Done. MongoDB data left intact."

gc: clean
	@echo "Removing Kafka tarball & extracted dir (local dev artifacts)..."
	@rm -f $(KAFKA_TGZ)
	@rm -rf $(KAFKA_DIR)
	@echo "GC complete. MongoDB data left intact."

really-gc: gc
	@echo "Aggressive cleanup: removing stray *.pyc across CA0"
	@find . -name "*.pyc" -delete || true
	@echo "really-gc complete."
