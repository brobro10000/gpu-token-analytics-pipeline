FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY producer.py .
COPY gpu_seed.json /data/gpu_seed.json
ENV GPU_SEED=/data/gpu_seed.json
USER 10001:10001
CMD ["python", "producer.py"]
