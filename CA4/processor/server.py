# import os
# from fastapi import FastAPI, HTTPException
# from pydantic import BaseModel, Field
# from typing import List, Optional, Any
# import time
#
# app = FastAPI(
#     title="CA4 Processor API (Local Dev)",
#     version="1.0.0",
# )
#
# # ---------------------------
# # Pydantic model for metadata
# # ---------------------------
#
# class ExtraFields(BaseModel):
#     pipeline: Optional[str] = "unknown"
#     notes: Optional[str] = None
#     gpu_hardware: Optional[Any] = None
#
# class MetadataPayload(BaseModel):
#     source_type: str = Field(..., example="image")
#     source_uri: str = Field(..., example="dog.jpg")
#     metadata_id: str
#     model_name: str
#     model_version: str
#     timestamp: int = Field(default_factory=lambda: int(time.time()))
#     embedding_dim: int
#     embedding: List[float]
#     extra: Optional[ExtraFields]
#
#
# # ---------------------------
# # POST /metadata
# # ---------------------------
#
# @app.post("/metadata")
# async def receive_metadata(payload: MetadataPayload):
#     """
#     Receives GPU/TPU-extracted metadata from Colab or other producers.
#     """
#
#     print("\n--- Received Metadata Document ---")
#     print(f"ID: {payload.metadata_id}")
#     print(f"Source: {payload.source_uri}")
#     print(f"Embedding dim: {payload.embedding_dim}")
#     print(f"Extra: {payload.extra}")
#     print("----------------------------------\n")
#
#     # Here you would normally:
#     # - Validate schema
#     # - Normalize payload
#     # - Produce to Kafka
#     # - Track metrics/logs
#
#     # For now: echo success response
#     return {
#         "status": "ok",
#         "message": "Metadata received",
#         "metadata_id": payload.metadata_id,
#         "embedding_dim": payload.embedding_dim,
#     }
#
#
# # ---------------------------
# # Health Check Endpoint
# # ---------------------------
#
# @app.get("/health")
# async def health_check():
#     return {"status": "healthy"}

import os
import time
import json
import uuid
from typing import List, Optional, Any

from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel, Field

# ---------------------------
# Config from environment
# ---------------------------

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP")  # set by Makefile
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "gpu-metadata")

app = FastAPI(
    title="CA4 Processor API (Local Dev)",
    version="1.0.0",
)

# ---------------------------
# Pydantic models
# ---------------------------


class ExtraFields(BaseModel):
    """
    Optional extra fields you may want to attach to a metadata document.
    """
    pipeline: Optional[str] = "unknown"
    notes: Optional[str] = None
    gpu_hardware: Optional[Any] = None  # raw gpu_info dict, if you want to embed it here


class MetadataPayload(BaseModel):
    """
    Shape of the JSON document sent from Colab (or other producers).
    Feel free to extend fields as needed.
    """
    metadata_id: str = Field(
        default_factory=lambda: str(uuid.uuid4()),
        description="Unique identifier for this metadata document.",
    )
    source_uri: Optional[str] = Field(
        default=None,
        description="Path/URL of the original sample (e.g. gs://, s3://, or local path).",
    )
    embedding: List[float] = Field(
        ...,
        description="Vector embedding produced by the GPU/TPU model.",
    )
    gpu_hardware: Optional[Any] = Field(
        default=None,
        description="GPU metadata dict (device name, memory, CUDA version, etc.).",
    )
    extra: Optional[ExtraFields] = Field(
        default=None,
        description="Optional additional structured fields.",
    )

    @property
    def embedding_dim(self) -> int:
        return len(self.embedding)


# ---------------------------
# Kafka producer (optional)
# ---------------------------

producer = None

if KAFKA_BOOTSTRAP:
    try:
        from kafka import KafkaProducer  # requires kafka-python

        producer = KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
        )
        print(f"[processor] KafkaProducer configured, bootstrap={KAFKA_BOOTSTRAP}")
    except Exception as e:
        # Don't crash the app if Kafka is unavailable – just log it.
        print(f"[processor] Failed to create KafkaProducer: {e}")
        producer = None
else:
    print("[processor] WARNING: KAFKA_BOOTSTRAP not set; events will not be sent to Kafka.")


def send_to_kafka(event: dict) -> None:
    """
    Synchronous helper used in a FastAPI background task to send to Kafka.
    """
    if producer is None:
        print("[processor] Kafka producer not configured; skipping send.")
        return

    try:
        future = producer.send(KAFKA_TOPIC, event)
        record_metadata = future.get(timeout=10)
        print(
            f"[processor] Sent event to Kafka topic='{record_metadata.topic}', "
            f"partition={record_metadata.partition}, offset={record_metadata.offset}"
        )
    except Exception as e:
        print(f"[processor] Error sending event to Kafka: {e}")


# ---------------------------
# POST /metadata
# ---------------------------


@app.post("/metadata")
async def receive_metadata(payload: MetadataPayload, background_tasks: BackgroundTasks):
    """
    Receives GPU/TPU-extracted metadata from Colab or other producers
    and forwards it to Kafka (if configured).
    """

    print("\n--- Received Metadata Document ---")
    print(f"metadata_id: {payload.metadata_id}")
    print(f"source_uri : {payload.source_uri}")
    print(f"embedding_dim: {payload.embedding_dim}")
    print(f"gpu_hardware present: {payload.gpu_hardware is not None}")
    print(f"extra: {payload.extra.dict() if payload.extra else None}")

    event = {
        "metadata_id": payload.metadata_id,
        "source_uri": payload.source_uri,
        "embedding": payload.embedding,
        "embedding_dim": payload.embedding_dim,
        "gpu_hardware": payload.gpu_hardware,
        "extra": payload.extra.dict() if payload.extra else None,
        "ingested_at": time.time(),
    }

    # If Kafka is configured, enqueue a background task to send the event.
    if producer is not None:
        background_tasks.add_task(send_to_kafka, event)
    else:
        print("[processor] Kafka not configured; event will only be logged locally.")

    return {
        "status": "ok",
        "message": "Metadata received",
        "metadata_id": payload.metadata_id,
        "embedding_dim": payload.embedding_dim,
        "kafka_enabled": producer is not None,
    }


# ---------------------------
# Health Check Endpoint
# ---------------------------


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "kafka_bootstrap": KAFKA_BOOTSTRAP,
        "kafka_enabled": producer is not None,
    }
