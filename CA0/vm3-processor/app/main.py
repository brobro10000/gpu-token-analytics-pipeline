import os, json, asyncio, time
from fastapi import FastAPI
from pymongo import MongoClient, ASCENDING
from confluent_kafka import Consumer
from collections import deque
from fastapi import FastAPI
from starlette_exporter import PrometheusMiddleware, handle_metrics

app = FastAPI()
app.add_middleware(PrometheusMiddleware)
app.add_route("/metrics", handle_metrics)

app = FastAPI()
BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "10.0.1.10:9092")
MONGO_URL = os.getenv("MONGO_URL", "mongodb://10.0.1.11:27017/ca0")
PRICE = float(os.getenv("PRICE_PER_HOUR_USD", "0.85"))

mongo = MongoClient(MONGO_URL)
db = mongo.get_default_database()
WINDOW = 30
window = deque()

def ensure_indexes():
    db.gpu_metrics.create_index([("ts", ASCENDING)])
    db.gpu_metrics.create_index([("host", ASCENDING), ("gpu_index", ASCENDING)])
    db.token_usage.create_index([("ts", ASCENDING)])
    db.token_usage.create_index([("model", ASCENDING)])

@app.get("/health")
def health(): return {"status": "ok"}

@app.get("/gpu/info")
def gpu_info():
    doc = db.gpu_metrics.find_one(sort=[("ts", -1)])
    return doc or {}

async def consume_loop():
    ensure_indexes()
    c = Consumer({"bootstrap.servers": BOOTSTRAP, "group.id": "processor", "auto.offset.reset": "earliest"})
    c.subscribe(["gpu.metrics.v1", "token.usage.v1"])
    try:
        while True:
            msg = c.poll(0.2)
            now = time.time()
            while window and now - window[0][0] > WINDOW: window.popleft()
            if not msg:
                await asyncio.sleep(0.05); continue
            if msg.error():
                continue
            obj = json.loads(msg.value())
            if msg.topic() == "gpu.metrics.v1":
                db.gpu_metrics.insert_one(obj)
            else:
                tokens = obj.get("prompt_tokens",0)+obj.get("completion_tokens",0)
                window.append((now, tokens))
                db.token_usage.insert_one(obj)
                total = sum(t for _,t in window)
                span = max(1, (now - window[0][0])) if window else 1
                tphr = total * (3600/span)
                if tphr>0:
                    db.token_usage.update_one({"ts": obj["ts"], "model": obj["model"]},
                                              {"$set": {"cost_per_token": PRICE/tphr}}, upsert=True)
    finally:
        c.close()

@app.on_event("startup")
async def startup(): asyncio.create_task(consume_loop())
