# AWS Setup Guide — CA0 (Manual Deployment on 4 VMs, No Docker)

This document describes how to provision and configure **four EC2 instances** in AWS to run the CA0 pipeline:

**Producers → Kafka → Processor → MongoDB**

---

## 1. Networking

1. Go to **VPC → Create VPC**:
   - Name: `ca0-vpc`
   - CIDR: `10.0.0.0/16`

2. Create a **Subnet**:
   - CIDR: `10.0.1.0/24`
   - AZ: `us-east-1a` (or your region)

3. Attach an **Internet Gateway** and add a default route `0.0.0.0/0 → IGW`.

4. Enable **DNS hostnames** on the VPC.

---

## 2. Security Groups

Create one Security Group per VM.

| Target VM (SG)  | Port  | Source                        | Purpose                    |
|-----------------|-------|-------------------------------|----------------------------|
| VM1 `sg-kafka`  | 22    | Admin IP                      | SSH                        |
|                 | 9092  | `sg-processor`, `sg-producers`| Kafka client traffic       |
| VM2 `sg-mongo`  | 22    | Admin IP                      | SSH                        |
|                 | 27017 | `sg-processor`                | DB writes from Processor   |
| VM3 `sg-processor` | 22 | Admin IP                      | SSH                        |
|                 | 8080  | Admin IP                      | `/health` endpoint         |
| VM4 `sg-producers` | 22 | Admin IP                      | SSH only                   |

> Outbound traffic: allow all (default).

---

## 3. Launch EC2 Instances

| VM   | Role       | Type     | AMI (Ubuntu 22.04 LTS) | Private IP |
|------|------------|----------|------------------------|------------|
| VM1  | Kafka      | t3.small | 22.04 LTS              | 10.0.1.10  |
| VM2  | MongoDB    | t3.small | 22.04 LTS              | 10.0.1.11  |
| VM3  | Processor  | t3.micro | 22.04 LTS              | 10.0.1.12  |
| VM4  | Producers  | t3.micro | 22.04 LTS              | 10.0.1.13  |

Steps:
1. Select AMI: **Ubuntu 22.04 LTS (64-bit x86)**.
2. Assign subnet `10.0.1.0/24`.
3. Set private IPs manually as shown above.
4. Attach correct Security Group.
5. Key Pair: use `ca0.pem`.
6. Storage: 8 GB gp3 is fine.

---

## 4. Baseline Setup (all VMs)

SSH into each VM and run:

```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y unzip curl wget git net-tools htop python3 python3-venv openjdk-17-jre-headless
````

Harden SSH:

```bash
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

(Optional) Enable UFW:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw enable
```

---

## 5. Install & Configure Each VM

### VM1 — Kafka

```bash
wget https://archive.apache.org/dist/kafka/3.7.0/kafka_2.13-3.7.0.tgz
tar xzf kafka_2.13-3.7.0.tgz
cd kafka_2.13-3.7.0

# Edit config
nano config/kraft/server.properties
# Set advertised.listeners=PLAINTEXT://10.0.1.10:9092

# Format storage & start broker
bin/kafka-storage.sh format -t $(uuidgen) -c config/kraft/server.properties
bin/kafka-server-start.sh config/kraft/server.properties
```

### VM2 — MongoDB

```bash
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo tee /usr/share/keyrings/mongodb-server-7.0.gpg
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl enable --now mongod
```

### VM3 — Processor

```bash
scp -i ~/.ssh/ca0.pem -r vm3-processor ubuntu@<VM3_PUBLIC_IP>:/home/ubuntu/
ssh -i ~/.ssh/ca0.pem ubuntu@<VM3_PUBLIC_IP>

cd vm3-processor/app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Environment
echo "KAFKA_BOOTSTRAP=10.0.1.10:9092" >> .env
echo "MONGO_URL=mongodb://10.0.1.11:27017/ca0" >> .env
echo "PRICE_PER_HOUR_USD=0.85" >> .env
echo "GPU_METRICS_SOURCE=seed" >> .env

uvicorn main:app --host 0.0.0.0 --port 8080
```

### VM4 — Producers

```bash
scp -i ~/.ssh/ca0.pem -r vm4-producers ubuntu@<VM4_PUBLIC_IP>:/home/ubuntu/
ssh -i ~/.ssh/ca0.pem ubuntu@<VM4_PUBLIC_IP>

cd vm4-producers
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export KAFKA_BOOTSTRAP=10.0.1.10:9092
python producer.py
```

---

## 6. Connectivity Checks

* VM3 → VM1 (Kafka):

  ```bash
  nc -vz 10.0.1.10 9092
  ```
* VM3 → VM2 (MongoDB):

  ```bash
  nc -vz 10.0.1.11 27017
  ```
* Laptop → VM3 (Processor health):

  ```bash
  curl http://<VM3_PUBLIC_IP>:8080/health
  ```

---

## 7. Functional Validation

1. **Create topics** (on VM1):

   ```bash
   bin/kafka-topics.sh --bootstrap-server 10.0.1.10:9092 --create --topic gpu.metrics.v1 --partitions 1 --replication-factor 1
   bin/kafka-topics.sh --bootstrap-server 10.0.1.10:9092 --create --topic token.usage.v1 --partitions 1 --replication-factor 1
   ```

2. **Run processor** (on VM3) and confirm `/health`:

   ```bash
   curl http://localhost:8080/health
   ```

3. **Run producer** (on VM4):

   ```bash
   python producer.py
   ```

4. **Verify Mongo data** (on VM2):

   ```bash
   mongosh --eval 'db.getSiblingDB("ca0").gpu_metrics.countDocuments()'
   mongosh --eval 'db.getSiblingDB("ca0").token_usage.findOne()'
   ```

---

## 8. Cost Control

* Use **t3.micro/small** only.
* Stop instances when not in use.
* Tag resources: `Course=CS5287, Assignment=CA0`.

---

## 9. Submission Checklist

* Config table with versions & IP\:Port.
* Network diagram.
* Screenshots:

    * EC2 instances list
    * Kafka topics list
    * Processor `/health`
    * Mongo counts and sample doc
* Note deviations (e.g., KRaft instead of ZooKeeper).


