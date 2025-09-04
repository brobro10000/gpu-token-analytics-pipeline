import json, os, time, random, datetime
from confluent_kafka import Producer

BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "10.0.1.10:9092")
GPU_SEED = os.getenv("GPU_SEED", "./gpu_seed.json")
p = Producer({"bootstrap.servers": BOOTSTRAP})

def send(topic, obj):
    p.produce(topic, json.dumps(obj).encode("utf-8")); p.poll(0)

def now():
    return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"

def main():
    with open(GPU_SEED) as f: seeds = json.load(f)
    for _ in range(20):
        s = random.choice(seeds)
        gpu = {**s, "ts": now(), "host": "vm4"}
        usage = {"ts": now(), "model":"llama-3-70b",
                 "prompt_tokens": random.randint(256, 2048),
                 "completion_tokens": random.randint(64, 512),
                 "latency_ms": random.randint(100, 800),
                 "gpu_index": s["gpu_index"]}
        send("gpu.metrics.v1", gpu)
        send("token.usage.v1", usage)
        time.sleep(0.5)
    p.flush()

if __name__ == "__main__":
    main()
