# CA0 — Full AWS Console Setup & VM Bring-up (No CLI)

**Goal:** Document the entire process we used to stand up CA0 using the **AWS web console only** (no AWS CLI), and then bootstrap each VM **individually** from the **root Makefile**. Includes the exact **Make command sequences** we ran for **bootstrap → setup → start → validate** on each VM.

---

## 0) What We’re Building

**Pipeline:** Producers → **Kafka (VM1)** → **Processor (VM3)** → **MongoDB (VM2)**
(Optional) Processor exposes `GET /health` on port 8080 for checks.

| VM  | Role      | Private IP (authoritative) | Ports (listen)  | Notes                                             |
| --- | --------- | -------------------------- | --------------- | ------------------------------------------------- |
| VM1 | Kafka     | `10.0.1.197`               | 9092            | Advertised on private IP so other VMs can connect |
| VM2 | MongoDB   | `10.0.1.86`                | 27017           | `--bind_ip_all`, published as `0.0.0.0:27017`     |
| VM3 | Processor | `10.0.1.112`               | 8080 (optional) | Consumes Kafka, writes to Mongo; `/health`        |
| VM4 | Producers | `10.0.1.85`                | —               | One-shot container that sends messages to Kafka   |

**Key principles**

* Use **private IPs** for all inter-VM service URLs.
* Use **public IPs only for SSH** from your laptop.
* Lock network paths with **Security Groups (SG-to-SG)**.
* Prefer **named volumes** for stateful services (Kafka/Mongo) and **exclude** service data from rsync.

---

## 1) Create the Network in the **AWS Console**

### 1.1 VPC & Subnet (public)

1. In the console, go to **VPC → Create VPC**.
2. Choose **VPC and more** (wizard).
3. Set:

    * **Name tag:** `ca0-vpc`
    * **IPv4 CIDR:** `10.0.0.0/16`
    * **Number of Availability Zones:** 1 (for simplicity)
    * **Public subnets:** 1
    * **Public subnet CIDR:** `10.0.1.0/24`
    * **NAT gateways:** None (not needed for this setup)
    * **VPC endpoints:** None (optional)
4. Create the stack. The wizard will:

    * Create the VPC, **public subnet**, **Internet Gateway**, and a **route table** with `0.0.0.0/0` via IGW.
5. After creation, open the **Subnet** you just made:

    * **Actions → Edit subnet settings → Enable auto-assign public IPv4** (so instances get public IPs for SSH).
6. In **VPC → Your VPCs → ca0-vpc → Actions → Edit VPC settings**, confirm **DNS hostnames** is enabled.

### 1.2 Security Groups (SGs)

Create four service SGs + one admin SG:

1. **Admin SG** (for SSH):

    * **Name:** `ca0-admin`
    * **Inbound rule:** Type **SSH**, Port **22**, Source **My IP** (or your office CIDR).
2. **Kafka SG:**

    * **Name:** `ca0-kafka`
    * **Inbound (later):** allow **TCP 9092** from **ca0-processor** and **ca0-producers**.
3. **Mongo SG:**

    * **Name:** `ca0-mongo`
    * **Inbound (later):** allow **TCP 27017** from **ca0-processor**.
4. **Processor SG:**

    * **Name:** `ca0-processor`
    * **Inbound (optional):** allow **TCP 8080** from **ca0-admin** (for `/health`).
5. **Producers SG:**

    * **Name:** `ca0-producers`
    * (No inbound needed; outbound defaults are fine.)

> After creating all five SGs, edit **Inbound rules** precisely:
>
> * On **ca0-kafka**: add **9092** with **source = ca0-processor** and another rule **9092** with **source = ca0-producers**.
> * On **ca0-mongo**: add **27017** with **source = ca0-processor**.
> * On **ca0-processor** (optional): add **8080** with **source = ca0-admin**.

**Why SG-to-SG?** It’s least-privilege and resilient to IP changes.

---

## 2) Create an EC2 **Key Pair** (for SSH)

1. In the console, open **EC2 → Key pairs → Create key pair**.
2. **Name:** `ca0` (or your preferred name), **Type:** RSA, **Format:** `.pem`.
3. Download the `.pem` and move it to `~/.ssh/ca0`; set permissions:

   ```bash
   chmod 600 ~/.ssh/ca0
   ```

---

## 3) Launch the **4 EC2 Instances** (Ubuntu 24.04 LTS)

Repeat these steps per instance (VM1..VM4), changing name, SGs, and **private IP**:

1. **EC2 → Launch instance**
2. **Name & tags:** `ca0-vm1-kafka` (then `ca0-vm2-mongo`, `ca0-vm3-processor`, `ca0-vm4-producers`)
3. **Application and OS Images:** Ubuntu Server **24.04 LTS (amd64)**
4. **Instance type:** `t3.small` (or larger if needed)
5. **Key pair:** select your `ca0` key
6. **Network settings:**

    * **VPC:** `ca0-vpc`
    * **Subnet:** your **public** subnet `10.0.1.0/24`
    * **Auto-assign public IP:** **Enable**
    * **Firewall (security groups):** **Attach two SGs** to each instance:

        * **Admin SG:** `ca0-admin`
        * **Service SG:** role-specific (Kafka, Mongo, Processor, Producers)
    * **Edit network interface** → **Primary private IPv4**:

        * VM1 (Kafka): **10.0.1.197**
        * VM2 (Mongo): **10.0.1.86**
        * VM3 (Processor): **10.0.1.112**
        * VM4 (Producers): **10.0.1.85**
7. **Storage:** defaults OK
8. **User data:** leave empty (we bootstrap via Make)
9. **Launch instance**

> After launch, copy each **Public IPv4 address**; you’ll place them in the root Makefile as `VM*_PUB`.

---

## 4) Fill in the **Root Makefile** Coordinates

In `CA0/Makefile` (already present in your repo), confirm these:

```make
SSH_KEY          ?= ~/.ssh/ca0
SSH_USER         ?= ubuntu
REMOTE_ROOT_DIR  ?= ~/gpu-token-analytics-pipeline
REMOTE_CA0_DIR   ?= $(REMOTE_ROOT_DIR)/CA0

# PUBLIC IPs (SSH only)
VM1_PUB ?= 3.222.207.91
VM2_PUB ?= 3.239.231.78
VM3_PUB ?= 34.200.237.224
VM4_PUB ?= 44.201.61.111

# PRIVATE IPs (service-to-service)
VM1_PRIV ?= 10.0.1.197   # Kafka
VM2_PRIV ?= 10.0.1.86    # MongoDB
VM3_PRIV ?= 10.0.1.112   # Processor
VM4_PRIV ?= 10.0.1.85    # Producers
```

> Public IPs are only used for **SSH**. All service configs use **private IPs**.

---

## 5) Bootstrap → Setup → Start — **Run From Your Laptop (Root Makefile)**

We removed the “one-shot” calls and now do **each VM individually**. These are the **exact sequences** to provision each node:

### VM1 — Kafka

```bash
# 1) Bootstrap the VM & sync repo
make vm1-bootstrap

# 2) Setup on the VM (ensures Kafka binds/advertises to VM1_PRIV)
make vm1-setup      # passes KAFKA_BIND_ADDR=$(VM1_PRIV) to the VM’s Makefile

# 3) Start Kafka
make vm1-up

# 4) (Optional) Create topics; tail logs
make vm1-logs
# or: make -C ~/gpu-token-analytics-pipeline/CA0/vm1-kafka topics
```

**Important**

* Ensure Kafka advertises `PLAINTEXT://10.0.1.197:9092`.
* **SG (Kafka)** must allow **9092** inbound from **ca0-processor** and **ca0-producers**.

---

### VM2 — MongoDB

```bash
make vm2-bootstrap      # base tools + rsync
make vm2-setup          # installs Docker/Compose on the VM if missing; builds
make vm2-up             # start MongoDB
make vm2-wait           # waits for mongod ping to succeed
make vm2-stats          # quick counts for ca0.gpu_metrics & ca0.token_usage
make vm2-logs
```

**Important**

* Mongo listens on `0.0.0.0:27017` in the VM (container publishes to host).
* **SG (Mongo)** must allow **27017** inbound **from ca0-processor** only.
* If you enable UFW on VM2, also allow:

  ```
  sudo ufw allow from 10.0.1.112 to any port 27017 proto tcp
  ```

---

### VM3 — Processor (Dockerized)

```bash
make vm3-bootstrap
make vm3-setup     # installs Docker/Compose on the VM if missing; builds image
make vm3-up
make vm3-wait
make vm3-health    # curls http://localhost:8080/health on VM3
make vm3-logs
```

**Env used by the container** (lives in `CA0/vm3-processor/.env`)

```env
KAFKA_BOOTSTRAP=10.0.1.197:9092
MONGO_URL=mongodb://10.0.1.86:27017/ca0
PRICE_PER_HOUR_USD=0.85
HOST=0.0.0.0
PORT=8080
```

**Important**

* If Mongo times out here, it’s usually **Security Group** on VM2; fix inbound 27017 per above.

---

### VM4 — Producers (One-shot)

```bash
make vm4-bootstrap
make vm4-setup
make vm4-doctor      # confirms Kafka reachability (uses private IP)
make vm4-run         # sends BATCH*2 messages; container exits when done
make vm4-logs
```

**Env (in `CA0/vm4-producers/.env`, or injected at run-time)**

```env
KAFKA_BOOTSTRAP=10.0.1.197:9092
GPU_SEED=/data/gpu_seed.json
BATCH=20
SLEEP_SEC=0.5
HOSTNAME=vm4
```

---

## 6) End-to-End Validation

```bash
# Optional: ensure topics exist on VM1
make -C ~/gpu-token-analytics-pipeline/CA0/vm1-kafka topics

# Processor ready on VM3
make vm3-up && make vm3-wait

# Run producers on VM4
make vm4-run

# Mongo counts on VM2 (should increase by BATCH for both collections)
make vm2-stats

# Spot-check latest doc via Processor API on VM3
# (ssh to VM3 or use the vm3-health/curl target)
curl -s http://localhost:8080/gpu/info | jq .
```

---

## 7) Security Group Matrix (Final State)

| Port            | Source SG → Dest SG           | Why                                        |
| --------------- | ----------------------------- | ------------------------------------------ |
| 22 (SSH)        | `ca0-admin` → all VMs         | Admin access from your IP (or office CIDR) |
| 9092 (Kafka)    | `ca0-processor` → `ca0-kafka` | Processor consumes from Kafka              |
| 9092 (Kafka)    | `ca0-producers` → `ca0-kafka` | Producers publish to Kafka                 |
| 27017 (Mongo)   | `ca0-processor` → `ca0-mongo` | Processor writes to Mongo                  |
| 8080 (optional) | `ca0-admin` → `ca0-processor` | Allow `/health` from admin IP only         |

> Default **egress** open on all SGs is fine for this setup.

---

## 8) Troubleshooting (the gotchas we actually hit)

* **Mongo timeout (VM3 → VM2:27017)**
  Almost always a **Security Group** issue. Fix **ca0-mongo** inbound: allow **27017** from **ca0-processor**. If UFW is enabled on VM2, also allow VM3’s private IP.
* **Kafka advertised listener wrong**
  Must be **VM1 private IP**; otherwise clients connect to the wrong host.
* **Rsync denies or deletes DB files**
  Exclude service data in rsync; prefer **named volumes** for Kafka/Mongo.
* **`docker compose exec` using `container_name`**
  Use the **Compose service name** (e.g., `mongo`) for exec/health commands.

---

## 9) Quick One-By-One Bring-up (from your laptop)

```bash
# VM1
make vm1-bootstrap && make vm1-setup && make vm1-up

# VM2
make vm2-bootstrap && make vm2-setup && make vm2-up && make vm2-wait

# VM3
make vm3-bootstrap && make vm3-setup && make vm3-up && make vm3-wait

# VM4
make vm4-bootstrap && make vm4-setup && make vm4-doctor && make vm4-run

# Validate
make vm2-stats
```

---

### Why this flow?

* You asked to **bootstrap each VM individually** and to use **setup from the local root** (root Makefile) rather than logging in manually.
* This preserves reproducibility, confines credentials to your laptop, and avoids fragile inline edits on remote hosts.

---

**Status:** With the steps above, you can recreate the VPC + SGs in the **AWS Console**, launch four Ubuntu instances with fixed **private IPs**, and bring each service up individually from the **root Makefile**, then validate end-to-end (Producer → Kafka → Processor → MongoDB).
