from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional, Any
import time

app = FastAPI(
    title="CA4 Processor API (Local Dev)",
    version="1.0.0",
)

# ---------------------------
# Pydantic model for metadata
# ---------------------------

class ExtraFields(BaseModel):
    pipeline: Optional[str] = "unknown"
    notes: Optional[str] = None
    gpu_hardware: Optional[Any] = None

class MetadataPayload(BaseModel):
    source_type: str = Field(..., example="image")
    source_uri: str = Field(..., example="dog.jpg")
    metadata_id: str
    model_name: str
    model_version: str
    timestamp: int = Field(default_factory=lambda: int(time.time()))
    embedding_dim: int
    embedding: List[float]
    extra: Optional[ExtraFields]


# ---------------------------
# POST /metadata
# ---------------------------

@app.post("/metadata")
async def receive_metadata(payload: MetadataPayload):
    """
    Receives GPU/TPU-extracted metadata from Colab or other producers.
    """

    print("\n--- Received Metadata Document ---")
    print(f"ID: {payload.metadata_id}")
    print(f"Source: {payload.source_uri}")
    print(f"Embedding dim: {payload.embedding_dim}")
    print(f"Extra: {payload.extra}")
    print("----------------------------------\n")

    # Here you would normally:
    # - Validate schema
    # - Normalize payload
    # - Produce to Kafka
    # - Track metrics/logs

    # For now: echo success response
    return {
        "status": "ok",
        "message": "Metadata received",
        "metadata_id": payload.metadata_id,
        "embedding_dim": payload.embedding_dim,
    }


# ---------------------------
# Health Check Endpoint
# ---------------------------

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
