import os
import time
import json
import uuid
import csv
from typing import List, Optional, Any

from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel, Field

# ---------------------------
# Config from environment
# ---------------------------

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP")  # set by Makefile
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "gpu-metadata")

# Simple file-based outbox for failed Kafka events
OUTBOX_FILE = os.getenv("KAFKA_OUTBOX_FILE", "kafka_outbox.csv")
OUTBOX_ENABLED = True  # flip to False if you ever want to disable outbox behavior

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


# ---------------------------
# Outbox helpers
# ---------------------------

def _append_to_outbox(event: dict) -> None:
    """
    Append a single event to the local outbox CSV so it can be retried on restart.

    Very simple format:
    - 2 columns: timestamp, JSON-serialized event

    Failures here should NEVER crash the API.
    """
    if not OUTBOX_ENABLED:
        return

    try:
        outbox_dir = os.path.dirname(OUTBOX_FILE)
        if outbox_dir and not os.path.exists(outbox_dir):
            os.makedirs(outbox_dir, exist_ok=True)

        with open(OUTBOX_FILE, "a", newline="") as f:
            writer = csv.writer(f)
            writer.writerow([time.time(), json.dumps(event)])
        print(f"[processor] Event written to outbox CSV: {OUTBOX_FILE}")
    except Exception as e:
        # Log but don't raise
        print(f"[processor] FAILED to write event to outbox CSV '{OUTBOX_FILE}': {e}")


def replay_outbox_events() -> None:
    """
    On startup, replay any events that were previously written to the outbox CSV.

    Behavior:
    - If the file does not exist or is empty, do nothing.
    - Try to re-send each event to Kafka.
    - If all re-sends succeed, truncate (clear) the file.
    - If any re-send fails, keep the file for a future retry.
    """
    if not OUTBOX_ENABLED:
        return

    if not os.path.exists(OUTBOX_FILE):
        return

    try:
        with open(OUTBOX_FILE, newline="") as f:
            reader = csv.reader(f)
            rows = list(reader)
    except Exception as e:
        print(f"[processor] FAILED to read outbox CSV '{OUTBOX_FILE}': {e}")
        return

    if not rows:
        return

    print(f"[processor] Replaying {len(rows)} event(s) from outbox: {OUTBOX_FILE}")

    for idx, row in enumerate(rows, start=1):
        try:
            if len(row) != 2:
                print(f"[processor] Skipping malformed outbox row #{idx}: {row!r}")
                continue

            _, event_json = row
            event = json.loads(event_json)

            # During replay we do NOT re-write failures back into the outbox here.
            send_to_kafka(event, allow_outbox_on_failure=False)
        except Exception as e:
            print(f"[processor] FAILED to replay outbox event #{idx}: {e}")
            print("[processor] Leaving outbox file in place for a future retry.")
            return

    # All events processed successfully (or safely skipped)
    try:
        open(OUTBOX_FILE, "w").close()
        print(f"[processor] Outbox CSV '{OUTBOX_FILE}' has been flushed.")
    except Exception as e:
        print(f"[processor] FAILED to truncate outbox CSV '{OUTBOX_FILE}': {e}")


# ---------------------------
# Kafka send helper
# ---------------------------

def send_to_kafka(event: dict, *, allow_outbox_on_failure: bool = True) -> None:
    """
    Synchronous helper used in a FastAPI background task to send to Kafka.

    On failure (e.g., Kafka timeout), the event is written to a simple CSV
    "outbox" so it can be replayed on the next server startup.
    """
    if producer is None:
        print("[processor] Kafka producer not configured; skipping send.")
        if allow_outbox_on_failure:
            _append_to_outbox(event)
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
        if allow_outbox_on_failure:
            _append_to_outbox(event)


# ---------------------------
# Startup hook: replay outbox
# ---------------------------

@app.on_event("startup")
async def _replay_outbox_on_startup() -> None:
    """
    On startup, attempt to replay any events stored in the local outbox CSV.
    """
    if producer is None:
        print("[processor] Kafka producer not configured; skipping outbox replay.")
        return

    print("[processor] Checking for any events in outbox to replay on startup...")
    replay_outbox_events()


# ---------------------------
# POST /metadata
# ---------------------------


@app.post("/metadata")
async def receive_metadata(payload: MetadataPayload, background_tasks: BackgroundTasks):
    """
    Receives GPU/TPU-extracted metadata from Colab or other producers
    and forwards it to Kafka (if configured).

    If Kafka is unavailable or times out, the event will be written to the
    local outbox CSV and replayed on a future restart.
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
    # If Kafka is misconfigured or goes down during send, send_to_kafka will
    # write the event into the outbox CSV.
    if producer is not None:
        background_tasks.add_task(send_to_kafka, event)
    else:
        print("[processor] Kafka not configured; event will only be logged locally.")
        if OUTBOX_ENABLED:
            _append_to_outbox(event)

    return {
        "status": "ok",
        "message": "Metadata received",
        "metadata_id": payload.metadata_id,
        "embedding_dim": payload.embedding_dim,
        "kafka_enabled": producer is not None,
        "outbox_enabled": OUTBOX_ENABLED,
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
        "outbox_file": OUTBOX_FILE if OUTBOX_ENABLED else None,
        "outbox_enabled": OUTBOX_ENABLED,
    }
