import json
import os
import time
from kafka import KafkaConsumer
from pymongo import MongoClient
from pymongo.errors import PyMongoError
from kafka.errors import KafkaError

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "kafka.platform.svc.cluster.local:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "gpu-metadata")

MONGO_URI = os.getenv("MONGO_URI", "mongodb://mongo.platform.svc.cluster.local:27017")
MONGO_DB = os.getenv("MONGO_DB", "ca4")
MONGO_COLLECTION = os.getenv("MONGO_COLLECTION", "gpu-metadata")

print(f"[worker] Starting CA4 worker…")
print(f"[worker] Kafka: {KAFKA_BOOTSTRAP}, topic={KAFKA_TOPIC}")
print(f"[worker] Mongo: {MONGO_URI}, db={MONGO_DB}, coll={MONGO_COLLECTION}")

def make_consumer():
    return KafkaConsumer(
        KAFKA_TOPIC,
        bootstrap_servers=KAFKA_BOOTSTRAP,
        auto_offset_reset="earliest",
        enable_auto_commit=True,
        group_id="ca4-worker",
        value_deserializer=lambda v: json.loads(v.decode("utf-8")),
    )

def main():
    mongo_client = MongoClient(MONGO_URI)
    coll = mongo_client[MONGO_DB][MONGO_COLLECTION]

    while True:
        try:
            consumer = make_consumer()
            print("[worker] Connected to Kafka, waiting for messages…")

            for msg in consumer:
                event = msg.value
                doc = {
                    "topic": msg.topic,
                    "partition": msg.partition,
                    "offset": msg.offset,
                    "metadata_id": event.get("metadata_id"),
                    "source_uri": event.get("source_uri"),
                    "embedding_dim": event.get("embedding_dim"),
                    "gpu_hardware": event.get("gpu_hardware"),
                    "extra": event.get("extra"),
                    "raw": event,
                    "ingested_at": time.time(),
                }
                try:
                    coll.insert_one(doc)
                    print(
                        f"[worker] wrote metadata_id={doc['metadata_id']} "
                        f"offset={msg.offset} to {MONGO_DB}.{MONGO_COLLECTION}"
                    )
                except PyMongoError as e:
                    print(f"[worker] Mongo write error: {e}")

        except KafkaError as e:
            print(f"[worker] Kafka error: {e}, retrying in 5s…")
            time.sleep(5)
        except Exception as e:
            print(f"[worker] Unexpected error: {e}, retrying in 5s…")
            time.sleep(5)

if __name__ == "__main__":
    main()
