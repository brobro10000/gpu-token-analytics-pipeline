#!/usr/bin/env bash
set -euo pipefail

echo "== VM1 (Kafka) =="
# ssh ubuntu@10.0.1.10 'cd CS5287/CA0/vm1-kafka && make up topics && make list-topics'

echo "== VM2 (Mongo) =="
# ssh ubuntu@10.0.1.11 'cd CS5287/CA0/vm2-mongo && make up && sleep 3 && make init-indexes'

echo "== VM3 (Processor) =="
# ssh ubuntu@10.0.1.12 'cd CS5287/CA0/vm3-processor && make build up && sleep 2 && make health'

echo "== VM4 (Producers) =="
# ssh ubuntu@10.0.1.13 'cd CS5287/CA0/vm4-producers && make build run-once'

echo "== Check counts on VM2 =="
# ssh ubuntu@10.0.1.11 'cd CS5287/CA0/vm2-mongo && make stats'
