import os
import json
import time
import random
from datetime import datetime, UTC
from confluent_kafka import Producer, KafkaException
from fastapi import FastAPI
from starlette_exporter import PrometheusMiddleware, handle_metrics

# --- Config (env-overridable) ---
BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "10.0.1.10:9092")
TOPIC_METRIC = os.getenv("TOPIC_METRIC", "gpu.metrics.v1")
TOPIC_TOKEN  = os.getenv("TOPIC_TOKEN",  "token.usage.v1")
GPU_SEED = os.getenv("GPU_SEED", "/data/gpu_seed.json")
GPU_SEED_LOCAL = os.getenv("GPU_SEED_LOCAL", "./gpu_seed.json")
BATCH = int(os.getenv("BATCH", "20"))
SLEEP_SEC = float(os.getenv("SLEEP_SEC", "0.5"))
HOSTNAME = os.getenv("HOSTNAME", "vm4")

# --- Kafka producer ---
producer = Producer({
    "bootstrap.servers": BOOTSTRAP,
    "client.id": "vm4-producer",
    "socket.timeout.ms": 10000,
    "message.timeout.ms": 30000,
    "retries": 3,
})

def dr_cb(err, msg):
    """Delivery report callback."""
    if err is not None:
        print(f"[ERROR] delivery failed: topic={msg.topic()} err={err}")
    # else: could log success if desired

def send(topic: str, obj: dict):
    try:
        producer.produce(topic, json.dumps(obj).encode("utf-8"), callback=dr_cb)
        producer.poll(0)
    except BufferError:
        # queue full; flush a bit and retry once
        producer.poll(0.5)
        producer.produce(topic, json.dumps(obj).encode("utf-8"), callback=dr_cb)
    except KafkaException as e:
        print(f"[ERROR] produce exception: {e}")
        raise

def now_iso_z() -> str:
    # timezone-aware UTC, with trailing 'Z'
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")

def load_seeds() -> list[dict]:
    """Try GPU_SEED first; on failure, fall back to GPU_SEED_LOCAL."""
    for path in (GPU_SEED, GPU_SEED_LOCAL):
        try:
            with open(path) as f:
                seeds = json.load(f)
            if not isinstance(seeds, list) or not seeds:
                raise ValueError("seed file is empty or not a list")
            print(f"[INFO] Loaded {len(seeds)} seeds from {path}")
            return seeds
        except Exception as e:
            print(f"[WARN] Failed to load {path}: {e}")
    raise RuntimeError("No valid seed file found (tried GPU_SEED and GPU_SEED_LOCAL)")

def main():
    app = FastAPI()
    app.add_middleware(PrometheusMiddleware)
    app.add_route("/metrics", handle_metrics)
    random.seed()  # system entropy
    seeds = load_seeds()
    sent = 0
    try:
        for _ in range(BATCH):
            s = random.choice(seeds)
            ts = now_iso_z()

            gpu = {
                **s,
                "ts": ts,
                "host": HOSTNAME,
            }

            usage = {
                "ts": ts,
                "model": "llama-3-70b",
                "prompt_tokens": random.randint(256, 2048),
                "completion_tokens": random.randint(64, 512),
                "latency_ms": random.randint(100, 800),
                "gpu_index": s.get("gpu_index", 0),
            }

            send(TOPIC_METRIC, gpu)
            send(TOPIC_TOKEN, usage)
            sent += 2
            time.sleep(SLEEP_SEC)

    except KeyboardInterrupt:
        print("\n[INFO] Interrupted, flushing…")
    finally:
        remaining = producer.flush(10)  # seconds
        if remaining == 0:
            print(f"[INFO] Done. Sent {sent} records (all flushed).")
        else:
            print(f"[WARN] Flush timed out; {remaining} message(s) may be pending.")

if __name__ == "__main__":
    main()
