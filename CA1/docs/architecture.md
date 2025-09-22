# CA1 – Infrastructure as Code (IaC) Rebuild of CA0

Context
- Recreate CA0 via code (Terraform/Ansible/etc.), idempotent, parameterized, secure secrets, and one-command deploy/destroy.
- Pipeline unchanged: Producers → Kafka → Processor → MongoDB (same as CA0), but fully automated.

> **Goal:** Recreate CA0’s 4-VM pipeline fully via code (Terraform + cloud-init + Docker Compose), with idempotent bring-up/tear-down and a single end-to-end verifier.

## Diagrams

* High-level context, component architecture, and provisioning/runtime sequence are captured in the PlantUML diagrams already included in the repo.

### Diagram Overview
![PlantUML-highlevel](https://www.plantuml.com/plantuml/svg/LLFTRXez4BttKyp7nITG8110oiz55KhKAgfeesp4LM-6tO6uUEsjFIQYLQK-H9-mJz8nBDdDrNfypioUEPwv3OoUOsdKV_nC9S5EhpnQLgpP4Cnd5p20Uvp3BB8haQc0vI90zucynxNp9Pp1p0QzCjI3lx__m3sJHzREmjgxKWgCb0fRRIlqM49uniAzQBk1DPf0BQHqrkNFaaB0FhQHt9MLisGvuxr8yfGpseqXfJ1dvw5pHpiohYBV0GmWaQemt-A6e9EKprr17VYfeAa4dLVzNsrt-J3lG_Qndphh7MeyVNZBhZiKxhqDZCR0_rBMhlKcUZgcp3vdRtCooZrnW0LQaUBJVp0Q7cQBOqAsEF2DeJpP5Q2pH1-4vcaZSH-2_a6X3-mgdQSlRcfrozbZfdufPQKnwCoDYmLq7mzPmookB77lsE-Hi5nSm1RNMpmaIzH2nidtZIjMDJPkOHEelCif1EThTD92fmajOau-rEWqQHBtOJ1u9mx23V3ha61LcVsmeC3UxPM0YIDIckEuEKwQuxIfA0PBIJo-nA0ok5yvjrLoVIeciAwVvrFg5xetrwFhSQ_56RSuYzJvtNjXZIz75vTjsaHe1LN6xU7Xv87mhaPNepPjAZGVhN1g9vJA5d1-VXAhxJTvN90vA89AhoPOigOv2qyfATHgeROL3je5cxImtDaGopRMjFNYDHCSUqcp8S7ACRjIfIL-fEzHUoh9ShXHij85oQIoXEc7EnraUD9QdW4JUjbHAwI7j7_4v6KI2zYXroZU1q5EmxtJA8CyF4osN7-9N4Mv5f4b-hriIIZTbgHcO4MsW2HBgLivnjBy0m00)
### Architecture diagram
![PlantUML-architecture](https://www.plantuml.com/plantuml/svg/bLPlR-BE4NxlJp7AxqM9hZROv7ftw8YE0Cb5EGB2a5HjAhIn1zXYxrgxw-IYzgH-Xtx3VfBEhWc6b4Rw9KhadNrczl6pyyVVj67Ab7dc6MuoX7ulXF_ywzymGwNOKgeSFi109XjK_YLNsa1F9MjkC36bGcXCcEBc1PwvMPDh2mfUOCO5ddgUtd1HCCLoq6kMocSkLh1acSQzdKJcXHGeJ6nUCWH5OPbOPVkGPyMAUvvI_2XgxTbJNB8oCpFyQNePNucSea26IxE74J95ZGMqF-uP5HCRQupsZJsbv7DVPbB1RsVkv-tcRCsJZK2j8Gn2pyjmXIAj3knsuKUrx7Qzhr_Dyloyri_FcM0hJ46XbgLAa12f4vHGbRBDlfL1umwgKJtn11lwr8jbnbDWbe66BgXI69uZfCmmM6RosHimlSOzn3NhDn-bDDgGSCsIGlaMx3csZgNdiSH81IT3iU82KK6Zb-PSmFNaz0IO1hVol88b6w839tKkJ9JyEztH2Vp3W_gsu2INQPbXy5GaBi1eF5ZSJVfGQN4KgZ4fRUeiLagMXTwvnLVlUN6XoP9WZR--ZMT7FHJcqY0GdlutP66u52mxhG-QzMP3xvVdKP8Gl7SVGwFKFZ9j_B22aSszw9AIW23sZS9Mu7wRuP_Wdn2NZm9DPGp969qvFm8wFu0gzjqeX0rRRjY3s4B3LWMaZGe8TId0oOt5GZlu5BIWSJDbItFw82PI6Ts1BwqlqOEOoO8dklCWV5WLPP2ZKRGEda9hCNA38YWrtHrPt44tlSkR7jI9vyxyTK0nWboAbKmVQvALBstjIDfCUcIQ74OMFBW0uXZyV123YmuahFKWg8OoJApOEtgBBRqTjuNZjhs9swln-yJQK2X9Lwwbggb5MshjO_fTqXts9jT0o32Y_ZMdOf9AqBfD39jhP9bPG-TpwpCjXxTtZgYJQ74n7i_YsRGtwUvkgbD9xbTS5_FfZ-vMgKwpkPEg4trgXP-QJWCV9jFh_d0n6KuNtyVpwM8U3xgjuFD7ktKrcIz6mna1uaLCc_rXLoEczdt8RTmVnl5u-huYPrQHj4nGwLgHzbQHisEAJ5xCMWfAAQT78iKoAsd3Tra9KK3CXZatloEZYEfWtXzEuoDKwU-m5lMgEibvnbStHmkMG4xNBMZq_q2xRDW29-y0Av5UWTDN9F7xmzw4KvWnbx5hNcZljNdv_hcjPA_gIcv9r0-NeyFbvCrowkrQb8is2jyQehU6zbl3cUKQRxibk6u9N1WKHaE3Pgf2JMF2lPt_rzze-VB7r8s4lrNkq84u_WvH14ibStZjzDO3ZdgqoSEMnY7-GHo9C3eU8Q88hXmgX_qxEnhcvdYO4AfszxzHA8Vtx_T8KD9iy3eYeR6TcgTUdRKaxhOhTc1I1QhIl4df3_Zaz7MbxzLLkU_KbqANEJdPLdmSMZKtYaySkJRxlH0-xBT2gBg7v-WxrpfG1ww6CpXeMlRjBbv7l9TaiapXP3VfeU4iFXVSpWqVhktGpBBjnmQTlFtSi7kNQ98rA2oa_NnhterWARFKQUf3MZaa5HmeyVmK2bHqDtRxNd634A1uWYNFqBdq5JAp4wL1b-WeZBVZjmFpotl8kL9IKO5KbJaVr3aV1ETsFH-u9tAl7wFwiLq_Kda8E-SVfJ4o1xbqJWSJD4vOPfjSs2OkRfn2RZjfGqZuYvGtYFHEjCNI9rI6Qqo3ZAuB1SdGdVpeNT_EXd-UKRC_70dkYygUVOH1vBsPZwy201Sf_aJjfcMmbn0DeplXwLxCR_HeFyl_2m00)
### Sequence diagram
![PlantUML-Sequence](https://www.plantuml.com/plantuml/svg/dPNDRk984CVlVehIx0Mq69iFAHbsDnhYaDc8P41y99T8gCTkS0kxo-ekXsHFUze7s7t3UP8j6yPuHZw52-wkVrN_wjzb-6H96ChJn255YOHWt8DlV_y7AscCsA99OPnboHjy--TVkC5mBmq4c6Pe9LmZaYKZCcZDUVlneUquTgzq9en8mSOYmeFIEzYAnCfQ94MDOMmmbK0chqV6nk0Xm0GD_38iFpy7Lx4AzrfQ2xrkhnOyCCQJYYY6lk_NpnAl3wmMExbKVqdeNVgE8q920nEzKreojx0mSLXDAbIPq0GVphq7ztSV2i7gzaV5-6a9u_anniy_1YT1dyteFUkzsEv5gU5bawR_hDcC7KPVJwf-ashmh3E38RU1vgGRDEc6fIxAGsdiIJTqd0cuLym_0ggwKbfHqtwM20sjntdGWULdsu4XS67-pgqqRYH8j9koH3aVhiW9NNus-2ATrIth2cT641WfI09NzPRvLot9Ms1EqZPe-51ebQPvfIrUrRPNDTQkvzsBN8TnGGajjhZRvOxRS50KdvcX5IQOHsxHD0yevnNfh1x1v5M6Z5BNdaRyr-z3_Xji9V4HmTZtNjAUMzAr7KwlgaJ7bF2O07a6RWIjQI64GVUYwyDq8RRKVjQdDWap5TeHxBAycqeolEY-z3gylvUwcnV3okiQQlyTg7stjB10xLTLcb4V2k7DDJ1gzvKnxzWfu7KeVAwE6IdK8W6b8_agROrhy0wkWLjTQi4sg2erizqAI_oYUUiN5QBHCBhqBtrcd7nv7C5qV3iTRwvdizLojHZFE_0m-_9vjbalxZimNzm5ayryijZyELilDklbJGry-0xmeLkRGIvHLMe6dxzHZ1g-vxHicwbNAfN62mtgiwrRD919ep1I8SXKaNNEvNcyviSAG0YZZ_v7ddGwu6c6QWwoCa1jyrJ2rc1wr9x3VFbFHj6nJF_2xrquayhwC3S9n4JPoFD-vokwAbtsOYaIYk6Fg-8t5MRJffSVSyfoWjRTt7PWlRXZf2PP92qPV6DsAKo41ysoJr97nV_E_m00)


## Components by VM

### VM1 — Kafka (Bitnami, KRaft mode)

* Single broker, internal **PLAINTEXT** on `:9092`.
* Advertised listener bound to VM1’s private IP (discovered at boot).
* Topics created idempotently: `gpu.metrics.v1`, `token.usage.v1`.
* Healthcheck: `kafka-broker-api-versions.sh …` with startup grace.
* **Lesson applied:** ensure host directory ownership for Bitnami UID `1001` before compose up to avoid `Permission denied` loops.

### VM2 — MongoDB 7.x

* Single node, named Docker volume `mongo_data` to avoid host UID/perm issues.
* **Init scripts (first boot only):**

    * `indexes.js` — creates indexes for `gpu_metrics`, `token_usage`, `gpus`.
    * `seed-gpus.js` — inserts two seed GPU docs (RTX 3090, A100 40GB).
* Healthcheck: `mongosh … db.runCommand({ ping: 1 })`.
* **Lesson applied:** use named volume instead of bind mount; auth can be enabled later without Terraform changes.

### VM3 — Processor (FastAPI + Uvicorn + confluent-kafka + pymongo)

* **Build-from-Git** at boot: Docker builds remote context from `CA0/vm3-processor` (ref/path templated).
* Consumes Kafka topics and writes to Mongo.
* Exposes `/health` and `/gpu/info`.
* Healthcheck: HTTP GET `/health`.
* **Lesson applied:** pick a health probe that doesn’t assume `curl` in slim images (use wget/Python or install curl).

### VM4 — Producers (Python + confluent-kafka)

* **Build-from-Git** at boot: Docker builds from `CA0/vm4-producers`.
* One-shot sender used by workflow verifier.
* Batch size and interval are parameterizable via `.env`.

## Networking & Security

* **VPC/Subnet:** private subnet; public IPs can be toggled via variable for dev convenience.
* **Security Groups (least privilege):**

    * `admin` — SSH (`22/tcp`) from workstation CIDR only.
    * `kafka` — `9092/tcp` only from **processor** and **producers** SGs.
    * `mongo` — `27017/tcp` only from **processor** SG.
    * `processor` — `8080/tcp` (health/API) from admin IP only.
* No internet-facing data ports.

**Ports matrix**

| VM            | Port  | Purpose    | Inbound allowed from             |
| ------------- | ----- | ---------- | -------------------------------- |
| VM1/Kafka     | 9092  | Broker     | VM3 Processor, VM4 Producers SGs |
| VM2/Mongo     | 27017 | DB         | VM3 Processor SG                 |
| VM3/Processor | 8080  | Health/API | Admin IP only                    |
| All           | 22    | SSH        | Admin IP only                    |

## Bootstrapping & Idempotency

All VMs use the same pattern:

1. **Terraform EC2** with `user_data_replace_on_change = true` (re-provision on template edits).
2. **cloud-init**:

    * Installs Docker Engine + Compose v2 plugin.
    * Writes app directory and Compose files.
    * Writes runtime `.env` from Terraform locals and/or IMDS (private IPs, topics, DB name, image tags).
3. **Systemd “refresh” one-shot service**:

    * Reconciles env, runs `docker compose up -d`, and **waits for health** before succeeding.
4. **Idempotency:**

    * Kafka topic creation uses `--if-not-exists`.
    * Mongo init scripts run **only on first** volume mount.
    * Reboot/stop-start safely re-applies desired state.

## Runtime Topology & Data Flow

1. **VM4 → VM1:** Producers publish to `gpu.metrics.v1` and `token.usage.v1`.
2. **VM1 → VM3:** Processor consumes both topics.
3. **VM3 → VM2:** Processor writes normalized docs to Mongo (`gpu_metrics`, `token_usage`); `/gpu/info` serves the latest GPU doc.

## Data Model (POC)

* **gpu\_metrics**: `{ host, gpu_index, utilization, mem_used_mb, power_w, ts, … }`
  Indexes: `{ ts }`, `{ host, gpu_index }`
* **token\_usage**: `{ model, prompt_tokens, completion_tokens, ts, cost_per_token, … }`
  Indexes: `{ ts }`, `{ model }`
* **gpus**: `{ gpu_index, name, price_per_hour_usd, ts }`
  Indexes on `name`, `gpu_index`; seeded with two docs.

## Health, Observability, Verification

* Compose-level **healthchecks** for all services feed the systemd refresh units.
* Makefile verify targets (remote SSH exec):

    * `verify-kafka`: broker health + topic list.
    * `verify-mongo`: health + seed counts + index presence.
    * `verify-processor` (expanded): `/health`, env echo, TCP reachability to Kafka/Mongo, `/gpu/info`.
    * `verify-workflow`: baseline counts → trigger producer → assert deltas → success banner.

## Parameterization (no hard-coded environment values)

* **IPs/Endpoints** discovered at apply/boot and injected into `.env`.
* **Topics, DB name, image tags, producer batch size** are Terraform variables with defaults; override via `*.tfvars`.
* **Build contexts**: VM3/VM4 images built **from Git subdirectories** (ref/subpath are variables).
* **Secrets note (current POC):** Mongo auth is not enabled, so no DB credentials are distributed; there are **no hardcoded secrets**. Provisioning uses the operator’s AWS CLI credentials (from shell IAM user/role) to create resources, not to inject application secrets. If/when auth is enabled, integrate AWS Secrets Manager/SSM + instance profiles without altering this architecture.

## Cost & Sizing (POC)

* **Instance types:** Kafka/Mongo → `t3.small`; Processor/Producers → `t3.micro` (x86 only).
* Rationale: low cost, adequate headroom, avoids ARM image mismatches.

## Risks & Mitigations

* **Kafka data perms (Bitnami UID 1001):** fix ownership at boot before compose up.
* **Mongo bind mount perms:** use **named volume**.
* **Slim image tooling:** avoid assuming `curl` or install it for health probes.
* **SG wiring (common pitfall):** ensure VM3→VM2 `27017/tcp` is allowed; verify with `nc` checks in `verify-processor`.
* **Reboots/stop-starts:** systemd refresh re-establishes desired state and waits for health.

## Compliance Mapping (Requirement → Where satisfied)

| Requirement                        | Where satisfied                                                                      |
| ---------------------------------- | ------------------------------------------------------------------------------------ |
| IaC (code-only create/destroy)     | Terraform modules + Makefile targets for deploy/teardown                             |
| Idempotent, parameterized          | `user_data_replace_on_change`, topic `--if-not-exists`, variables for topics/DB/tags |
| No hardcoded env values            | Runtime values via Terraform/IMDS; Git-based builds; no secrets embedded             |
| Kafka operational with topics      | VM1 Compose + topic creation script                                                  |
| Mongo operational with schema/seed | VM2 init scripts + healthcheck                                                       |
| Processor online API               | VM3 `/health`, `/gpu/info`                                                           |
| Producer triggers data             | VM4 one-shot sender driven by Makefile                                               |
| End-to-end proof                   | `make verify-workflow` baseline→trigger→delta assertions                             |

## Operations Runbooks (quick)

* **Deploy:** `make deploy`
* **Verify:** `make verify-all` (or individual `verify-*`)
* **Reset Mongo data (optional):** `make mongo-factory-reset` (down `-v`; bring up; seeds reapply)
* **Teardown:** `make down`

## Deferred / Stretch

* **Mongo auth + Secrets Manager/SSM** with EC2 instance profiles and boot-time fetch/rotation.
* **Remote TF state** (S3 + DynamoDB) for team collaboration.
* **Scheduled producers** via systemd timer for periodic ingestion.
* **CI lint/security**: `tflint`, `tfsec`/`checkov`.
