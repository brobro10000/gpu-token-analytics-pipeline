## =====================================================================
## CA0 Root Makefile
## - Local Dev (no Docker/Compose): Kafka (KRaft) + Processor + Producer
## - Remote VM Bootstrapper (no Docker): install directly on 4 AWS VMs
## =====================================================================
#
## -----------------------------
## Local Dev: Versions & Paths
## -----------------------------
#KAFKA_VERSION        ?= 3.7.0
#KAFKA_SCALA          ?= 2.13
#KAFKA_TGZ            ?= kafka_$(KAFKA_SCALA)-$(KAFKA_VERSION).tgz
#KAFKA_URL            ?= https://archive.apache.org/dist/kafka/$(KAFKA_VERSION)/$(KAFKA_TGZ)
#KAFKA_DIR            ?= $(PWD)/kafka_$(KAFKA_SCALA)-$(KAFKA_VERSION)
#KAFKA_BIN            := $(KAFKA_DIR)/bin
#KAFKA_SERVER_PROPS   := $(KAFKA_DIR)/config/kraft/server.properties
#KAFKA_PID_FILE       := /tmp/kafka-ca0.pid
#KAFKA_LOG_FILE       := /tmp/kafka-ca0.log
#KAFKA_DATA_DIR      ?= $(PWD)/.kafka-data
#KAFKA_SERVER_LOCAL  ?= $(KAFKA_DIR)/config/kraft/server.local.properties
#
## -----------------------------
## Local Dev: App / DB wiring
## -----------------------------
#BOOTSTRAP            ?= localhost:9092
#MONGO_URL            ?= mongodb://localhost:27017/ca0
#MONGO_DB             ?= ca0
#MONGO_SHELL          ?= mongosh
#PRICE_PER_HOUR_USD   ?= 0.85
#UVICORN_PORT         ?= 8080
#PYTHON               ?= python3
#
#PROC_DIR             := vm3-processor/app
#PROD_DIR             := vm4-producers
#PROC_VENV            := $(PROC_DIR)/.venv
#PROD_VENV            := $(PROD_DIR)/.venv
#
## -----------------------------
## Remote VM Bootstrapper (SSH)
## -----------------------------
#SSH_USER     ?= ubuntu
#SSH_KEY      ?= ~/.ssh/ca0
#SSH_OPTS     ?= -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
#
## Private IPs per architecture
#VM1_IP       ?= 10.0.1.197   # Kafka (KRaft)
#VM2_IP       ?= 10.0.1.86   # MongoDB
#VM3_IP       ?= 10.0.1.112   # Processor
#VM4_IP       ?= 10.0.1.85   # Producers
#
## Public IPs per architecture
#VM1_PUBLIC_IP    ?= 3.222.207.91
#VM2_PUBLIC_IP    ?= 3.239.231.78
#VM3_PUBLIC_IP    ?= 34.200.237.224
#VM4_PUBLIC_IP    ?= 44.201.61.111
#
## Remote app wiring
#KAFKA_BOOTSTRAP ?= $(VM1_IP):9092
#REMOTE_MONGO_URL?= mongodb://$(VM2_IP):27017/ca0
#PRICE_PER_HOUR_REMOTE ?= 0.85
#
## Kafka (remote)
#RK_KAFKA_VER    ?= 3.7.0
#RK_SCALA_VER    ?= 2.13
#RK_KAFKA_TGZ    ?= kafka_$(RK_SCALA_VER)-$(RK_KAFKA_VER).tgz
#RK_KAFKA_URL    ?= https://archive.apache.org/dist/kafka/$(RK_KAFKA_VER)/$(RK_KAFKA_TGZ)
#RK_KAFKA_DIR    ?= /opt/kafka
#RK_KAFKA_DATA   ?= /var/lib/kafka
#RK_KAFKA_LOG    ?= /var/log/kafka
#RK_KAFKA_SVC    ?= kafka.service
#RK_CLUSTER_ID   ?= 76520600
#
## Local source folders to deploy remotely
#PROC_SRC    ?= vm3-processor/app/
#PROD_SRC    ?= vm4-producers/
#
## Remote install locations
#PROC_DST    ?= /opt/processor
#PROD_DST    ?= /opt/producers
#
## Helpers
#ssh = ssh $(SSH_OPTS) -i $(SSH_KEY) $(SSH_USER)@$1
#scp = scp $(SSH_OPTS) -i $(SSH_KEY)
#
## -----------------------------
## PHONY
## -----------------------------
#.PHONY: help \
#        up down status \
#        kafka-download kafka-start kafka-stop kafka-restart kafka-status kafka-clean kafka-reset \
#        topics-create topics-delete topics-list \
#        processor-venv processor-run processor-kill \
#        producer-venv producer-run \
#        health mongo-counts db-clear db-drop \
#        clean gc really-gc purge \
#        vm1-setup vm1-start vm1-topics vm1-logs \
#        vm2-setup vm2-start vm2-logs vm2-stats \
#        vm3-setup vm3-service vm3-restart vm3-logs vm3-health \
#        vm4-setup vm4-runonce vm4-service vm4-logs \
#        ping matrix
#
## -----------------------------
## HELP
## -----------------------------
#help:
#	@echo "===== Local Dev (on your laptop) ====="
#	@echo "  make up                 - Start Kafka, create topics, print next steps"
#	@echo "  make down               - Stop Kafka"
#	@echo "  make status             - Kafka status + health + Mongo counts"
#	@echo "  make kafka-*            - Download/start/stop/reset Kafka (KRaft)"
#	@echo "  make topics-*           - Create/delete/list topics"
#	@echo "  make processor-venv     - Create venv + install FastAPI deps"
#	@echo "  make processor-run      - Run FastAPI locally on :$(UVICORN_PORT)"
#	@echo "  make producer-venv      - Create venv for producer"
#	@echo "  make producer-run       - Run producer locally"
#	@echo "  make db-clear|db-drop   - Clear collections or drop DB '$(MONGO_DB)'"
#	@echo "  make clean|gc|really-gc|purge - Cleanup tiers"
#	@echo ""
#	@echo "===== Remote VM Bootstrapper (AWS) ====="
#	@echo "  VM1 (Kafka):     vm1-setup | vm1-start | vm1-topics | vm1-logs"
#	@echo "  VM2 (MongoDB):   vm2-setup | vm2-start | vm2-stats  | vm2-logs"
#	@echo "  VM3 (Processor): vm3-setup | vm3-service | vm3-restart | vm3-logs | vm3-health"
#	@echo "  VM4 (Producers): vm4-setup | vm4-runonce | vm4-service | vm4-logs"
#	@echo "  Connectivity:    ping  |  matrix"
#	@echo ""
#	@echo "Override SSH vars if needed:"
#	@echo "  SSH_USER, SSH_KEY, VM{1..4}_IP  (current: $(SSH_USER), $(SSH_KEY), $(VM1_IP)/$(VM2_IP)/$(VM3_IP)/$(VM4_IP))"
#
## ======================================================
## Local Dev: Top-level flows
## ======================================================
#up: kafka-download kafka-start topics-create
#	@echo "== Next steps in NEW terminals =="
#	@echo "  1) make processor-venv && make processor-run"
#	@echo "  2) make producer-venv  && make producer-run"
#	@echo "Then verify:"
#	@echo "  make mongo-counts && make health"
#
#down: kafka-stop
#status: kafka-status health mongo-counts
#
## -----------------------------
## Local Dev: Kafka (KRaft)
## -----------------------------
#$(KAFKA_TGZ):
#	curl -L -o $(KAFKA_TGZ) $(KAFKA_URL)
#
#$(KAFKA_SERVER_LOCAL): $(KAFKA_SERVER_PROPS)
#	@mkdir -p $(KAFKA_DATA_DIR)
#	@sed 's|^log.dirs=.*|log.dirs=$(KAFKA_DATA_DIR)|' $(KAFKA_SERVER_PROPS) > $(KAFKA_SERVER_LOCAL)
#
#kafka-download: $(KAFKA_TGZ)
#	@echo "Extracting $(KAFKA_TGZ) -> $(KAFKA_DIR)"
#	@tar xzf $(KAFKA_TGZ)
#
#kafka-start: $(KAFKA_SERVER_LOCAL)
#	@if [ ! -d "$(KAFKA_DIR)" ]; then echo "Kafka not found. Run: make kafka-download"; exit 1; fi
#	@if [ ! -f "$(KAFKA_DATA_DIR)/meta.properties" ]; then \
#	  echo "Formatting KRaft storage at $(KAFKA_DATA_DIR) ..."; \
#	  $(KAFKA_BIN)/kafka-storage.sh format -t $$(uuidgen) -c $(KAFKA_SERVER_LOCAL); \
#	fi
#	@echo "Starting Kafka in background..."
#	@nohup $(KAFKA_BIN)/kafka-server-start.sh $(KAFKA_SERVER_LOCAL) > $(KAFKA_LOG_FILE) 2>&1 & echo $$! > $(KAFKA_PID_FILE)
#	@sleep 2
#	@echo "Kafka PID: $$(cat $(KAFKA_PID_FILE))  (logs: $(KAFKA_LOG_FILE))"
#
#kafka-stop:
#	@if [ -f "$(KAFKA_PID_FILE)" ]; then \
#	  echo "Stopping Kafka PID $$(cat $(KAFKA_PID_FILE))"; \
#	  kill $$(cat $(KAFKA_PID_FILE)) >/dev/null 2>&1 || true; \
#	  rm -f $(KAFKA_PID_FILE); \
#	else echo "Kafka not running (no $(KAFKA_PID_FILE))"; fi
#
#kafka-restart: kafka-stop kafka-start
#
#kafka-status:
#	@if [ -f "$(KAFKA_PID_FILE)" ]; then echo "Kafka running (PID $$(cat $(KAFKA_PID_FILE)))"; else echo "Kafka not running"; fi
#	@if [ -f "$(KAFKA_LOG_FILE)" ]; then echo "--- tail $(KAFKA_LOG_FILE) ---"; tail -n 5 $(KAFKA_LOG_FILE); fi
#
#kafka-clean:
#	@rm -f $(KAFKA_PID_FILE) $(KAFKA_LOG_FILE)
#	@echo "Kafka PID/log files removed."
#
#kafka-reset: kafka-stop
#	@rm -rf $(KAFKA_DATA_DIR)
#	@rm -f  $(KAFKA_PID_FILE) $(KAFKA_LOG_FILE)
#	@echo "Kafka data reset. Run 'make kafka-start' to reformat & start."
#
## -----------------------------
## Local Dev: Topics
## -----------------------------
#topics-create:
#	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --create --topic gpu.metrics.v1 --partitions 1 --replication-factor 1 || true
#	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --create --topic token.usage.v1  --partitions 1 --replication-factor 1 || true
#	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --list
#
#topics-delete:
#	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --delete --topic gpu.metrics.v1 || true
#	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --delete --topic token.usage.v1 || true
#	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --list
#
#topics-list:
#	@$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --list
#
## -----------------------------
## Local Dev: Processor (FastAPI)
## -----------------------------
#processor-venv:
#	cd $(PROC_DIR) && $(PYTHON) -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt
#
#processor-run:
#	cd $(PROC_DIR) && \
#	. .venv/bin/activate && \
#	export KAFKA_BOOTSTRAP=$(BOOTSTRAP) MONGO_URL=$(MONGO_URL) PRICE_PER_HOUR_USD=$(PRICE_PER_HOUR_USD) && \
#	echo "Processor on :$(UVICORN_PORT)" && \
#	uvicorn main:app --reload --port $(UVICORN_PORT)
#
#processor-kill:
#	-pkill -f "uvicorn main:app" || true
#
## -----------------------------
## Local Dev: Producer
## -----------------------------
#producer-venv:
#	cd $(PROD_DIR) && $(PYTHON) -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt
#
#producer-run:
#	cd $(PROD_DIR) && \
#	. .venv/bin/activate && \
#	export KAFKA_BOOTSTRAP=$(BOOTSTRAP) && \
#	$(PYTHON) producer.py
#
## -----------------------------
## Local Dev: Verification
## -----------------------------
#health:
#	@curl -sS http://localhost:$(UVICORN_PORT)/health || echo "Processor not responding"
#
#mongo-counts:
#	@$(MONGO_SHELL) --quiet --eval 'db.getSiblingDB("$(MONGO_DB)").gpu_metrics.countDocuments()'
#	@$(MONGO_SHELL) --quiet --eval 'db.getSiblingDB("$(MONGO_DB)").token_usage.findOne()'
#
## -----------------------------
## Local Dev: Database cleanup
## -----------------------------
#db-clear:
#	@echo "[WARN] Clearing collections in '$(MONGO_DB)'..."
#	@$(MONGO_SHELL) --quiet --eval 'db.getSiblingDB("$(MONGO_DB)").gpu_metrics.drop()'
#	@$(MONGO_SHELL) --quiet --eval 'db.getSiblingDB("$(MONGO_DB)").token_usage.drop()'
#	@echo "[OK] Collections dropped."
#
#db-drop:
#	@echo "[DANGER] Dropping database '$(MONGO_DB)'..."
#	@$(MONGO_SHELL) --quiet --eval 'db.getSiblingDB("$(MONGO_DB)").dropDatabase()'
#	@echo "[OK] Database dropped."
#
## -----------------------------
## Local Dev: Cleanup / GC
## -----------------------------
#clean: kafka-stop kafka-clean
#	@echo "Cleaning Python caches & venvs..."
#	@find $(PROC_DIR) -name "__pycache__" -type d -exec rm -rf {} + || true
#	@find $(PROD_DIR) -name "__pycache__" -type d -exec rm -rf {} + || true
#	@rm -rf $(PROC_VENV) $(PROD_VENV)
#	@echo "Done. MongoDB data left intact. (Use 'make db-clear' or 'make db-drop' to wipe data.)"
#
#gc: clean
#	@echo "Removing Kafka tarball & extracted dir (local dev artifacts)..."
#	@rm -f $(KAFKA_TGZ)
#	@rm -rf $(KAFKA_DIR)
#	@echo "GC complete. MongoDB data left intact. (Use 'make db-clear' or 'make db-drop'.)"
#
#really-gc: gc
#	@echo "Aggressive cleanup: removing stray *.pyc across CA0"
#	@find . -name "*.pyc" -delete || true
#	@echo "really-gc complete. MongoDB data left intact."
#
#purge: really-gc db-drop
#	@echo "[OK] Purge complete: code artifacts + Kafka + Mongo DB data cleaned."
#
## ======================================================
## Remote VM Bootstrapper (No Docker)
## ======================================================
#
## ---------- VM1: Kafka (KRaft) ----------
#vm1-setup:
#	@$(call ssh,$(VM1_IP)) 'sudo bash -lc "\
#	  set -e; \
#	  apt-get update -y; \
#	  apt-get install -y curl tar openjdk-17-jre-headless jq; \
#	  id -u kafka >/dev/null 2>&1 || useradd -r -m -d $(RK_KAFKA_DIR) -s /usr/sbin/nologin kafka; \
#	  mkdir -p $(RK_KAFKA_DIR) $(RK_KAFKA_DATA) $(RK_KAFKA_LOG); chown -R kafka:kafka $(RK_KAFKA_DIR) $(RK_KAFKA_DATA) $(RK_KAFKA_LOG); \
#	  test -f /tmp/$(RK_KAFKA_TGZ) || curl -fsSL $(RK_KAFKA_URL) -o /tmp/$(RK_KAFKA_TGZ); \
#	  tar -xzf /tmp/$(RK_KAFKA_TGZ) -C $(RK_KAFKA_DIR) --strip-components=1; chown -R kafka:kafka $(RK_KAFKA_DIR); \
#	  cat >/etc/kafka-server.properties <<EOF\
#process.roles=broker,controller\n\
#node.id=1\n\
#controller.quorum.voters=1@$(VM1_IP):9093\n\
#\n\
#listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://$(VM1_IP):9093\n\
#advertised.listeners=PLAINTEXT://$(VM1_IP):9092\n\
#listener.security.protocol.map=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT\n\
#inter.broker.listener.name=PLAINTEXT\n\
#\n\
#log.dirs=$(RK_KAFKA_DATA)\n\
#num.partitions=1\n\
#auto.create.topics.enable=false\n\
#EOF\n\
#	  if [ ! -f $(RK_KAFKA_DATA)/meta.properties ] || ! grep -q \"cluster.id=$(RK_CLUSTER_ID)\" $(RK_KAFKA_DATA)/meta.properties 2>/dev/null; then \
#	    KAFKA_LOG4J_OPTS=\"-Dlog4j.configuration=file:$(RK_KAFKA_DIR)/config/log4j.properties\" \
#	    $(RK_KAFKA_DIR)/bin/kafka-storage.sh format --config /etc/kafka-server.properties --cluster-id $(RK_CLUSTER_ID) --ignore-formatted; \
#	  fi; \
#	  cat >/etc/systemd/system/$(RK_KAFKA_SVC) <<EOF\
#[Unit]\n\
#Description=Apache Kafka (KRaft)\n\
#After=network.target\n\
#\n\
#[Service]\n\
#User=kafka\n\
#Group=kafka\n\
#Environment=KAFKA_LOG4J_OPTS=-Dlog4j.configuration=file:$(RK_KAFKA_DIR)/config/log4j.properties\n\
#ExecStart=$(RK_KAFKA_DIR)/bin/kafka-server-start.sh /etc/kafka-server.properties\n\
#ExecStop=$(RK_KAFKA_DIR)/bin/kafka-server-stop.sh\n\
#Restart=on-failure\n\
#RestartSec=5\n\
#LimitNOFILE=100000\n\
#StandardOutput=append:$(RK_KAFKA_LOG)/server.log\n\
#StandardError=append:$(RK_KAFKA_LOG)/error.log\n\
#\n\
#[Install]\n\
#WantedBy=multi-user.target\n\
#EOF\n\
#	  systemctl daemon-reload; echo OK"'
#
#vm1-start:
#	@$(call ssh,$(VM1_IP)) 'sudo systemctl enable $(RK_KAFKA_SVC); sudo systemctl restart $(RK_KAFKA_SVC); sudo systemctl --no-pager status $(RK_KAFKA_SVC) || true'
#
#vm1-topics:
#	@$(call ssh,$(VM1_IP)) '$(RK_KAFKA_DIR)/bin/kafka-topics.sh --bootstrap-server $(VM1_IP):9092 --create --topic gpu.metrics.v1 --partitions 1 --replication-factor 1 || true'
#	@$(call ssh,$(VM1_IP)) '$(RK_KAFKA_DIR)/bin/kafka-topics.sh --bootstrap-server $(VM1_IP):9092 --create --topic token.usage.v1  --partitions 1 --replication-factor 1 || true'
#	@$(call ssh,$(VM1_IP)) '$(RK_KAFKA_DIR)/bin/kafka-topics.sh --bootstrap-server $(VM1_IP):9092 --list'
#
#vm1-logs:
#	@$(call ssh,$(VM1_IP)) 'sudo tail -n 200 -F $(RK_KAFKA_LOG)/server.log'
#
## ---------- VM2: MongoDB 7.0 ----------
#vm2-setup:
#	@$(call ssh,$(VM2_IP)) 'sudo bash -lc "\
#	  set -e; \
#	  apt-get update -y; apt-get install -y gnupg curl; \
#	  curl -fsSL https://pgp.mongodb.com/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg; \
#	  echo \"deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse\" > /etc/apt/sources.list.d/mongodb-org-7.0.list; \
#	  apt-get update -y; apt-get install -y mongodb-org; \
#	  sed -i \"s/^  bindIp:.*/  bindIp: 0.0.0.0/\" /etc/mongod.conf; \
#	  systemctl daemon-reload; \
#	  if command -v ufw >/dev/null 2>&1; then ufw allow from $(VM3_IP) to any port 27017 proto tcp || true; fi; \
#	  echo OK"'
#
#vm2-start:
#	@$(call ssh,$(VM2_IP)) 'sudo systemctl enable mongod; sudo systemctl restart mongod; sudo systemctl --no-pager status mongod || true'
#
#vm2-logs:
#	@$(call ssh,$(VM2_IP)) 'sudo journalctl -u mongod -n 200 -f'
#
#vm2-stats:
#	@$(call ssh,$(VM2_IP)) 'mongosh --quiet --eval "db.getSiblingDB(\"ca0\").gpu_metrics.countDocuments()"'
#	@$(call ssh,$(VM2_IP)) 'mongosh --quiet --eval "db.getSiblingDB(\"ca0\").token_usage.findOne()" || true'
#
## ---------- VM3: Processor (FastAPI) ----------
#vm3-setup:
#	@echo ">> Deploying processor to $(VM3_IP) ..."
#	@$(call ssh,$(VM3_IP)) 'sudo apt-get update -y && sudo apt-get install -y python3-venv python3-pip rsync curl'
#	@$(scp) -r $(PROC_SRC) $(SSH_USER)@$(VM3_IP):/tmp/processor-src
#	@$(call ssh,$(VM3_IP)) 'sudo bash -lc "\
#	  set -e; \
#	  useradd -r -m -d $(PROC_DST) -s /usr/sbin/nologin processor 2>/dev/null || true; \
#	  mkdir -p $(PROC_DST); rsync -a --delete /tmp/processor-src/ $(PROC_DST)/; chown -R processor:processor $(PROC_DST); \
#	  sudo -u processor python3 -m venv $(PROC_DST)/.venv; \
#	  sudo -u processor $(PROC_DST)/.venv/bin/pip install --upgrade pip; \
#	  if [ -f $(PROC_DST)/requirements.txt ]; then sudo -u processor $(PROC_DST)/.venv/bin/pip install -r $(PROC_DST)/requirements.txt; fi; \
#	  echo \"KAFKA_BOOTSTRAP=$(KAFKA_BOOTSTRAP)\" >  $(PROC_DST)/.env; \
#	  echo \"MONGO_URL=$(REMOTE_MONGO_URL)\"     >> $(PROC_DST)/.env; \
#	  echo \"PRICE_PER_HOUR_USD=$(PRICE_PER_HOUR_REMOTE)\" >> $(PROC_DST)/.env; \
#	  echo \"GPU_METRICS_SOURCE=seed\"          >> $(PROC_DST)/.env; \
#	  chown processor:processor $(PROC_DST)/.env; \
#	  echo OK"'
#
#vm3-service:
#	@$(call ssh,$(VM3_IP)) 'sudo bash -lc "\
#	  cat >/etc/systemd/system/processor.service <<EOF\n\
#[Unit]\n\
#Description=CA0 Processor (FastAPI)\n\
#After=network.target\n\
#\n\
#[Service]\n\
#User=processor\n\
#Group=processor\n\
#EnvironmentFile=$(PROC_DST)/.env\n\
#WorkingDirectory=$(PROC_DST)\n\
#ExecStart=$(PROC_DST)/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8080 --workers 1\n\
#Restart=on-failure\n\
#\n\
#[Install]\n\
#WantedBy=multi-user.target\n\
#EOF\n\
#	  systemctl daemon-reload; systemctl enable processor.service; systemctl restart processor.service; systemctl --no-pager status processor.service || true"'
#
#vm3-restart:
#	@$(call ssh,$(VM3_IP)) 'sudo systemctl restart processor.service && sudo systemctl --no-pager status processor.service || true'
#
#vm3-logs:
#	@$(call ssh,$(VM3_IP)) 'sudo journalctl -u processor.service -n 200 -f'
#
#vm3-health:
#	@$(call ssh,$(VM3_IP)) 'curl -fsS http://localhost:8080/health || true'
#
## ---------- VM4: Producers (Python) ----------
#vm4-setup:
#	@echo ">> Deploying producers to $(VM4_IP) ..."
#	@$(call ssh,$(VM4_IP)) 'sudo apt-get update -y && sudo apt-get install -y python3-venv python3-pip rsync curl'
#	@$(scp) -r $(PROD_SRC) $(SSH_USER)@$(VM4_IP):/tmp/producers-src
#	@$(call ssh,$(VM4_IP)) 'sudo bash -lc "\
#	  set -e; \
#	  useradd -r -m -d $(PROD_DST) -s /usr/sbin/nologin producers 2>/dev/null || true; \
#	  mkdir -p $(PROD_DST)/data; rsync -a --delete /tmp/producers-src/ $(PROD_DST)/; chown -R producers:producers $(PROD_DST); \
#	  test -f $(PROD_DST)/data/gpu_seed.json || printf \"[%s]\" \"{\"\"gpu_index\"\":0,\"\"name\"\":\"\"A100 40GB\"\",\"\"utilization\"\":0.5,\"\"mem_used_mb\"\":12000,\"\"mem_total_mb\"\":40960,\"\"power_w\"\":210,\"\"price_per_hour_usd\"\":3.2}\" > $(PROD_DST)/data/gpu_seed.json; \
#	  sudo -u producers python3 -m venv $(PROD_DST)/.venv; \
#	  sudo -u producers $(PROD_DST)/.venv/bin/pip install --upgrade pip; \
#	  if [ -f $(PROD_DST)/requirements.txt ]; then sudo -u producers $(PROD_DST)/.venv/bin/pip install -r $(PROD_DST)/requirements.txt; fi; \
#	  echo OK"'
#
#vm4-runonce:
#	@$(call ssh,$(VM4_IP)) 'sudo bash -lc "\
#	  KAFKA_BOOTSTRAP=$(KAFKA_BOOTSTRAP) TOPIC_METRIC=gpu.metrics.v1 TOPIC_TOKEN=token.usage.v1 GPU_SEED=$(PROD_DST)/data/gpu_seed.json \
#	  $(PROD_DST)/.venv/bin/python $(PROD_DST)/producer.py"'
#
#vm4-service:
#	@$(call ssh,$(VM4_IP)) 'sudo bash -lc "\
#	  cat >/etc/systemd/system/producers.service <<EOF\n\
#[Unit]\n\
#Description=CA0 Producers (one-shot)\n\
#\n\
#[Service]\n\
#Type=oneshot\n\
#User=producers\n\
#Group=producers\n\
#WorkingDirectory=$(PROD_DST)\n\
#Environment=KAFKA_BOOTSTRAP=$(KAFKA_BOOTSTRAP)\n\
#Environment=TOPIC_METRIC=gpu.metrics.v1\n\
#Environment=TOPIC_TOKEN=token.usage.v1\n\
#Environment=GPU_SEED=$(PROD_DST)/data/gpu_seed.json\n\
#ExecStart=$(PROD_DST)/.venv/bin/python $(PROD_DST)/producer.py\n\
#EOF\n\
#	  cat >/etc/systemd/system/producers.timer <<EOF\n\
#[Unit]\n\
#Description=Run producers every minute\n\
#\n\
#[Timer]\n\
#OnBootSec=30s\n\
#OnUnitActiveSec=60s\n\
#AccuracySec=1s\n\
#\n\
#[Install]\n\
#WantedBy=timers.target\n\
#EOF\n\
#	  systemctl daemon-reload; systemctl enable producers.timer; systemctl start producers.timer; systemctl --no-pager status producers.timer || true"'
#
#vm4-logs:
#	@$(call ssh,$(VM4_IP)) 'sudo journalctl -u producers.service -n 200 -f'
#
## ---------- Connectivity Quick Checks ----------
#ping:
#	@echo ">> Check VM3 -> VM1 (Kafka:9092) and VM3 -> VM2 (Mongo:27017)"
#	@$(call ssh,$(VM3_IP)) 'nc -vz $(VM1_IP) 9092 || telnet $(VM1_IP) 9092 || true'
#	@$(call ssh,$(VM3_IP)) 'nc -vz $(VM2_IP) 27017 || telnet $(VM2_IP) 27017 || true'
#	@echo ">> Check VM4 -> VM1 (Kafka:9092)"
#	@$(call ssh,$(VM4_IP)) 'nc -vz $(VM1_IP) 9092 || telnet $(VM1_IP) 9092 || true'
#
#matrix:
#	@echo "Inbound rules to enforce (SG + UFW):"
#	@echo "  VM1 (Kafka)     9092/TCP  <- SG: processor, producers"
#	@echo "  VM2 (MongoDB)   27017/TCP <- SG: processor"
#	@echo "  VM3 (Processor) 8080/TCP  <- Admin IP only"
#	@echo "  All VMs: 22/TCP <- Admin IP"

# ===== CA0 Root Makefile — Remote install into 4 AWS VMs (no Docker) =====
# From your laptop, run targets that SSH into each VM, install software, sync repo,
# configure services, and start/stop them. Service-to-service uses PRIVATE IPs.
# SSH uses PUBLIC IPs. Requires: rsync, ssh, make on your laptop.

# -------------------------
# Project / repo paths
# -------------------------
REPO_LOCAL_ROOT ?= $(PWD)/..                 # local path that contains CS5287/
REPO_NAME       ?= gpu-token-analytics-pipeline
REMOTE_ROOT_DIR ?= ~/$(REPO_NAME)            # target dir on VMs
REMOTE_CA0_DIR  ?= $(REMOTE_ROOT_DIR)/CA0

# -------------------------
# Who/where to SSH
# -------------------------
SSH_KEY   ?= ~/.ssh/ca0
SSH_USER  ?= ubuntu
SSH_OPTS  := -i $(SSH_KEY) -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30

# PUBLIC IPs (for SSH)
VM1_PUB ?= 3.222.207.91    # Kafka
VM2_PUB ?= 3.239.231.78   # Mongo
VM3_PUB ?= 34.200.237.224   # Processor
VM4_PUB ?= 44.201.61.111  # Producers

# PRIVATE IPs (for internal wiring)
VM1_PRIV       ?= 10.0.1.197   # Kafka (KRaft)
VM2_PRIV       ?= 10.0.1.86   # MongoDB
VM3_PRIV       ?= 10.0.1.112   # Processor
VM4_PRIV       ?= 10.0.1.85   # Producers

# -------------------------
# App-level wiring
# -------------------------
KAFKA_BOOTSTRAP ?= $(VM1_PRIV):9092
MONGO_URL       ?= mongodb://$(VM2_PRIV):27017/ca0
PRICE_PER_HOUR  ?= 0.85
UVICORN_PORT    ?= 8080

# -------------------------
# Kafka (VM1) versions/paths
# -------------------------
KAFKA_VERSION   ?= 3.7.0
KAFKA_SCALA     ?= 2.13
KAFKA_TGZ       ?= kafka_$(KAFKA_SCALA)-$(KAFKA_VERSION).tgz
KAFKA_URL       ?= https://archive.apache.org/dist/kafka/$(KAFKA_VERSION)/$(KAFKA_TGZ)
KAFKA_DIR       ?= /opt/kafka_$(KAFKA_SCALA)-$(KAFKA_VERSION)
KAFKA_USER      ?= kafka
KAFKA_DATA_DIR  ?= /var/lib/kafka
KAFKA_LOG_DIR   ?= /var/log/kafka

# -------------------------
# Helpers
# -------------------------
define ssh-run
	ssh $(SSH_OPTS) $(SSH_USER)@$(1) 'bash -lc "$(2)"'
endef

# rsync local repo to remote
define rsync-repo
	rsync -az --delete -e "ssh $(SSH_OPTS)" $(REPO_LOCAL_ROOT)/$(REPO_NAME)/ $(SSH_USER)@$(1):$(REMOTE_ROOT_DIR)/
endef

# -------------------------
# BOOTSTRAP: base packages + repo sync (per VM)
# -------------------------
vm1-bootstrap:
	$(call ssh-run,$(VM1_PUB), \
	  'sudo apt-get update && sudo apt-get install -y git make rsync curl tar openjdk-17-jre-headless && mkdir -p $(REMOTE_ROOT_DIR)' )
	$(call rsync-repo,$(VM1_PUB))

vm2-bootstrap:
	$(call ssh-run,$(VM2_PUB), \
	  'sudo apt-get update && sudo apt-get install -y git make rsync curl gnupg && mkdir -p $(REMOTE_ROOT_DIR)' )
	$(call rsync-repo,$(VM2_PUB))

vm3-bootstrap:
	$(call ssh-run,$(VM3_PUB), \
	  'sudo apt-get update && sudo apt-get install -y git make rsync curl python3 python3-venv python3-pip build-essential librdkafka-dev && mkdir -p $(REMOTE_ROOT_DIR)' )
	$(call rsync-repo,$(VM3_PUB))

vm4-bootstrap:
	$(call ssh-run,$(VM4_PUB), \
	  'sudo apt-get update && sudo apt-get install -y git make rsync curl python3 python3-venv python3-pip build-essential librdkafka-dev && mkdir -p $(REMOTE_ROOT_DIR)' )
	$(call rsync-repo,$(VM4_PUB))

# -------------------------
# VM1 (Kafka) — install/config as systemd service (KRaft single node)
# -------------------------
vm1-setup: vm1-bootstrap
	# Create user/dirs and install Kafka
	$(call ssh-run,$(VM1_PUB), \
	  'set -e; \
	   sudo useradd -r -s /usr/sbin/nologin -M $(KAFKA_USER) || true; \
	   sudo mkdir -p $(KAFKA_DIR) $(KAFKA_DATA_DIR) $(KAFKA_LOG_DIR); \
	   cd /tmp; curl -L -o $(KAFKA_TGZ) $(KAFKA_URL); \
	   sudo tar xzf $(KAFKA_TGZ) -C /opt; \
	   sudo chown -R $(KAFKA_USER):$(KAFKA_USER) $(KAFKA_DIR) $(KAFKA_DATA_DIR) $(KAFKA_LOG_DIR); \
	   # Generate minimal KRaft config for single node \
	   cat $(KAFKA_DIR)/config/kraft/server.properties | \
	     sed "s|^log.dirs=.*|log.dirs=$(KAFKA_DATA_DIR)|" | \
	     sed "s|^#*process.roles=.*|process.roles=broker,controller|" | \
	     sed "s|^#*node.id=.*|node.id=1|" | \
	     sed "s|^#*controller.listener.names=.*|controller.listener.names=CONTROLLER|" | \
	     sed "s|^#*listeners=.*|listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093|" | \
	     sed "s|^#*advertised.listeners=.*|advertised.listeners=PLAINTEXT://$(VM1_PRIV):9092|" | \
	     sed "s|^#*inter.broker.listener.name=.*|inter.broker.listener.name=PLAINTEXT|" | \
	     sed "s|^#*controller.quorum.voters=.*|controller.quorum.voters=1@$(VM1_PRIV):9093|" \
	     | sudo tee $(KAFKA_DIR)/config/kraft/server.ca0.properties >/dev/null; \
	   # Format KRaft storage (idempotent) \
	   if [ ! -f $(KAFKA_DATA_DIR)/meta.properties ]; then \
	     sudo -u $(KAFKA_USER) $(KAFKA_DIR)/bin/kafka-storage.sh format -t $$((uuidgen)) -c $(KAFKA_DIR)/config/kraft/server.ca0.properties; \
	   fi; \
	   # systemd unit \
	   sudo tee /etc/systemd/system/kafka.service >/dev/null <<EOF ; \
[Unit]
Description=Apache Kafka (KRaft, single node)
After=network.target

[Service]
Type=simple
User=$(KAFKA_USER)
Group=$(KAFKA_USER)
Environment="KAFKA_HEAP_OPTS=-Xms512m -Xmx512m"
ExecStart=$(KAFKA_DIR)/bin/kafka-server-start.sh $(KAFKA_DIR)/config/kraft/server.ca0.properties
ExecStop=$(KAFKA_DIR)/bin/kafka-server-stop.sh
Restart=on-failure
StandardOutput=append:$(KAFKA_LOG_DIR)/kafka.out
StandardError=append:$(KAFKA_LOG_DIR)/kafka.err

[Install]
WantedBy=multi-user.target
EOF \
	   sudo systemctl daemon-reload; sudo systemctl enable kafka; \
	  ')

vm1-up:
	$(call ssh-run,$(VM1_PUB), 'sudo systemctl start kafka && sleep 3 && systemctl --no-pager --full status kafka || true')

vm1-down:
	$(call ssh-run,$(VM1_PUB), 'sudo systemctl stop kafka || true')

vm1-topics:
	$(call ssh-run,$(VM1_PUB), \
	  '$(KAFKA_DIR)/bin/kafka-topics.sh --bootstrap-server $(VM1_PRIV):9092 \
	     --create --if-not-exists --topic gpu.metrics.v1 --partitions 1 --replication-factor 1; \
	   $(KAFKA_DIR)/bin/kafka-topics.sh --bootstrap-server $(VM1_PRIV):9092 \
	     --create --if-not-exists --topic token.usage.v1 --partitions 1 --replication-factor 1; \
	   $(KAFKA_DIR)/bin/kafka-topics.sh --bootstrap-server $(VM1_PRIV):9092 --list')

# -------------------------
# VM2 (MongoDB 7) — native install + enable
# -------------------------
vm2-setup: vm2-bootstrap
	$(call ssh-run,$(VM2_PUB), \
	  'set -e; \
	   source /etc/os-release; CODENAME=$$VERSION_CODENAME; \
	   curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor; \
	   echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $$CODENAME/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list; \
	   sudo apt-get update; sudo apt-get install -y mongodb-org; \
	   sudo systemctl enable --now mongod; \
	   sleep 3; systemctl --no-pager --full status mongod || true; \
	  ')

vm2-stats:
	$(call ssh-run,$(VM2_PUB), \
	  'mongosh --quiet --eval '\''db.getSiblingDB("ca0").gpu_metrics.countDocuments()'\'' ; \
	   mongosh --quiet --eval '\''db.getSiblingDB("ca0").token_usage.countDocuments()'\'' || true')

# -------------------------
# VM3 (Processor) — FastAPI via systemd (uvicorn)
# -------------------------
vm3-setup: vm3-bootstrap
	$(call ssh-run,$(VM3_PUB), \
	  'set -e; cd $(REMOTE_CA0_DIR)/vm3-processor/app; \
	   python3 -m venv .venv; . .venv/bin/activate; pip install --upgrade pip; \
	   pip install -r requirements.txt; \
	   # Write environment file \
	   sudo tee /etc/ca0-processor.env >/dev/null <<EOF ; \
KAFKA_BOOTSTRAP=$(KAFKA_BOOTSTRAP)
MONGO_URL=$(MONGO_URL)
PRICE_PER_HOUR_USD=$(PRICE_PER_HOUR)
UVICORN_PORT=$(UVICORN_PORT)
EOF \
	   # systemd unit \
	   sudo tee /etc/systemd/system/ca0-processor.service >/dev/null <<'EOF' ; \
[Unit]
Description=CA0 Processor (FastAPI)
After=network.target

[Service]
Type=simple
User=$(SSH_USER)
WorkingDirectory=$(REMOTE_CA0_DIR)/vm3-processor/app
EnvironmentFile=/etc/ca0-processor.env
ExecStart=$(REMOTE_CA0_DIR)/vm3-processor/app/.venv/bin/uvicorn main:app --host 0.0.0.0 --port $${UVICORN_PORT}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF \
	   sudo systemctl daemon-reload; sudo systemctl enable ca0-processor; \
	  ')

vm3-up:
	$(call ssh-run,$(VM3_PUB), 'sudo systemctl start ca0-processor && sleep 2 && curl -sS http://localhost:$(UVICORN_PORT)/health || true')

vm3-down:
	$(call ssh-run,$(VM3_PUB), 'sudo systemctl stop ca0-processor || true')

vm3-health:
	$(call ssh-run,$(VM3_PUB), 'curl -sS http://localhost:$(UVICORN_PORT)/health || true')

# -------------------------
# VM4 (Producers) — install venv + run on demand
# -------------------------
vm4-setup: vm4-bootstrap
	$(call ssh-run,$(VM4_PUB), \
	  'set -e; cd $(REMOTE_CA0_DIR)/vm4-producers; \
	   python3 -m venv .venv; . .venv/bin/activate; pip install --upgrade pip; \
	   pip install -r requirements.txt; \
	  ')

vm4-run:
	$(call ssh-run,$(VM4_PUB), \
	  'cd $(REMOTE_CA0_DIR)/vm4-producers; . .venv/bin/activate; \
	   export KAFKA_BOOTSTRAP=$(KAFKA_BOOTSTRAP); \
	   python3 producer.py \
	  ')

# -------------------------
# One-shot flows
# -------------------------
ca0-bootstrap: vm1-bootstrap vm2-bootstrap vm3-bootstrap vm4-bootstrap
	@echo "[OK] Base packages installed and repo synced on all VMs."

ca0-setup: vm1-setup vm2-setup vm3-setup vm4-setup
	@echo "[OK] All VMs installed and configured."

ca0-up: vm1-up vm1-topics vm3-up vm4-run
	@echo "[OK] Pipeline invoked. Check Mongo counts on VM2 with 'make vm2-stats'."

ca0-down: vm3-down vm1-down
	@echo "[OK] Processor and Kafka stopped."

# -------------------------
# Convenience SSH
# -------------------------
ssh-kafka:     ; ssh $(SSH_OPTS) $(SSH_USER)@$(VM1_PUB)
ssh-mongo:     ; ssh $(SSH_OPTS) $(SSH_USER)@$(VM2_PUB)
ssh-processor: ; ssh $(SSH_OPTS) $(SSH_USER)@$(VM3_PUB)
ssh-producers: ; ssh $(SSH_OPTS) $(SSH_USER)@$(VM4_PUB)

# -------------------------
# Safety notes:
# - Ensure your Security Groups allow:
#   * SSH 22 from your IP (sg-admin)
#   * Kafka 9092 from sg-processor + sg-producers
#   * Mongo 27017 from sg-processor
#   * Processor 8080 from your IP
# - PRIVATE IPs are used for service wiring (no egress charges).
# - PUBLIC IPs are only used for SSH here.
# -------------------------
