FROM python:3.12-slim

# Faster, quieter, reproducible-ish installs
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# If confluent-kafka ever complains, uncomment the apt-get lines below
# RUN apt-get update && apt-get install -y --no-install-recommends \
#       librdkafka1 ca-certificates curl \
#     && rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .
RUN pip install -r requirements.txt

COPY app/ .

# non-root
USER 10001:10001

EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
