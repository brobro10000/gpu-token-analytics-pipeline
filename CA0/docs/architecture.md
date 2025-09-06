# CA0 – Manual Deployment on 4 VMs with GPU Cost/Token Use Case

Context
- Manually provision 4 VMs, install services, wire the pipeline, secure ports, and validate end-to-end.
- Chosen cloud: AWS in one VPC/Subnet (private IPs), but local setups are fine if topology matches.

Diagrams
- Logical architecture:
![PlantUML](https://www.plantuml.com/plantuml/svg/XLDXRzis4FtENt7BbzbOPLkoiIJ-C3HptCJet0bHacA30OEMQ5iJnHD8AfutzB_lI2cHWxKD35WYx-cHz-wzzyPoRUjIiX_iNfG2dlADvieocrifO7OrWW0cSFKvWSUbWTv7lYqu_0HBL3kaPwmn5SQWRjwpEXNQz6bn4p_038qTtcCX56Eco5N5DI_1x7c6XrpjOCkb4IUL4XMcUusb0AlhqqgAPOLAA9lOenIWHMgvsad164yjQZYxoifSGUyFh3KiuluPS0D-Zp65cI00TL2RG71ZW_0C_cK0MsAcocCyWt0qyBzX-FDA9VL62TliXRGNJJmTuVnd00tZupA4miaH_5EiL8iEHolLQ3GUd0z6CBqSNKOhzIVYHo4geMdxSX31D0elGkX9JBdSaqhDXOdn5Ny4fPCvstJquKfvwQz_1KyVdO_2yvMQePIaIOxAJ65NrUjIM9sdvXrO9_-wDdmdsZEYLsUCeNeUONSAtVWQqqAugNuWnQxY1KmlHXVKd9jhIpw5Ju_BtuR9SZ5CXCXQ-l4h-WbKpwxewCSdz547Q0acHF25VM7iHsYcobDtFzOiWk0NSCfF8Kbk8OgWLuWZe9B7_Yj4z2PY_2PYyXt4OF3CSNj_7uCJ1th3lU3Ixjy1LcuMNCAGXZ7CrHRxhfyuhuJCbO13hYa0p1tHDTJunXa6UgqeVOAClm59KPcwx21jqy_syCw0ta7drWS6TMRy9Kuc25nba295WgmPUAkmbwZ1cHllIlNKKvxbF2XbK1t7ZLDTvHJPGaoP4vuYQuHkW6GEbd7BDzoG7vmpZH3Pu2-3Yf3U_x3DfMZHy_ary_sGlFuGc7PQQi6pbo8HVxj6D5JSSYatF2swOgUIb-KqAL-jduI7RkjNBb8L_JdLrgJQskzwOHEHrlJP4RXIQBbF8rFevCztUmkuzGbFRgP0DyD3CyUjnf85O7R1In1VbaqksCE7pr3cMgCcYMwOK1auMlO_ygWZR-R_DNPlu--GZ3iIRslFqKPn4REvUff2VBUOpTVn_6vz-_l3tVeXkMQV4CJVLdDGmXvG5r2XjWQsg9tZklFUqrjToly0)
- Hardware/capacity architecture:
![Hardware Architecture](https://www.plantuml.com/plantuml/png/lLVDRXit4BxhAGOkqguKwqVoJrAvCYBBQEB6ZWNBYIy12cftj4jebroGN2jgKS2dehcsVOAYw2lqtaVnatH8SQLDLAC_XzxMvCpm-sQ--GG_quOfKsHfpN2J8eo67HZp75Ck4ExlVeQnab4Hej9m__sFy9BDvWo2RWzoIkE6Iw7hxeRYGjHQAdYkP96ximifOdbwKglfEHUKm3BG2OlaWeiOPYpLMBb9c8WMYXk3OkjEOMYOY0dVjpM04waYL2EPqcEV71uUrhwhX8OoowL0OVu-LCZe7nICc65JfX-Ch6t0xGnl9l1cF88sJ8gfG0C15mQLO6bJYdG9a-UWYXHrVGUOXjiyT4KTZfqt5zs-x--9adDK4BoyOZDJVojUJmjX2kZrMfrzEB-Uq61-WHV88YgbtuepeGb0Y7qmUosTiJI5uDtJmph1CFjnUS9KThXFnQw65ttemVCJ238kwhkmVt_tqrFxTqwZVYjEkPvJGCUUnFaUJ2Qd3ktSGdDueTBadMkPyv1U9iI2i3GQ7sYZqO0WxzpV_PPtkolIniPJ4MhSXlbUlwAVOPv3CABa8aEb_oNzZ8TAUkBksnFk4fsIMtUB6p4Fjwbv35xHL0Zpb8TCzw7H6C7z-ry_8EeAXINiac6f7ikoroyt0fwqtlsNiLO6-bU3VFpn5FUsc6OMGBNr-_tAYWUd11VEH8pQ_4-Dzq_RHVeCciqcV9dAXRPVjVBI_dNizTU7l9YcN2UG4GOM8-48nf3fkAs1nR72c1cirroqotEpxTDZciUYCZ4m1B6S5oW_sveBjtckKvIu0EjAgDlq1WHoPlrfCUZMIxpZig8rDI4DEkpkG_4uCI1dQz4t6kje3IZOD4MBYCQ9n2bhD6hWUdmf45Xe-2t26c6EQeCU5jmaN023s6hJfqsibxihsDx3cLJMtNtecGWLMbto6OmWuKQ3IUWrvAdbmKG4AOjjzOMkeOWSCq_PkzJKkTH7bAVI69bPpcu2ZlDDihJ5DO92BGiLebup_UhD1IJ8SdWCvrmKxmXpJ31OcA3x2H68aGPIaeztUkSQ8inaKxCP7gtzopBqWhASVKAZuVNcMq3gQgRCe0YNz4rCyvpesNsjYXkyz2UeRgqJa_ZhBbtJEbEBp7AhANwr7-o7qrFP3mi8FhMyrfsuuGgZQnxJSpDsAvLZxTvSI3MtGz5e7Y2bQ5xqobdx4g92UOJLZbs-N95dqoDATaP1gGh9xJ8YWf4FFk74oaZ85Rzb1Fzil5lgb1KcsIAzTkq7QTjzSgmtePf_GtJMnC_TbeoN9f6Y_ShQagQkyt0bWAuV-8mBB6KUiXJN6mlMNYEGmWgsFHg_zb5Ng7CC3QGyuyPQTfcmvTpRh4hZUPXL6U6ehUCzfnBYT0c4fotGs15QpJ9HTdgOv-cIi8VpPgvGwq8HRmcHN0Xj5B8C9kUN6XAPHbluR7K_PCYOIKX9kIHk7FK6BDFkpW6yJiWbuYGl38LEDkrV_ygwFSEeJsTq2WDd1EIh3J1VsmdInwJkBeFnW8nGj_Mklnfe3Aqtxi9aq6trQ1cxhGCRIxj0cnqfARDLNLjkuRf_GrylLkKMWuszxiBD89gMVaillBX__qEdzQHUSoo6XP4wPCwWh9cpL4EWhUVParnoONHzFOArtlgWtJGaiUSpgkCiqzdRCOp_-BtRwvJ-U63HTpAulBA3EtxIUNHaKVe2NC0YGQSpYyjbT0yo6BuwjU5Vx7SUGH1AcReXGhT3rUY-tlA8l4FqWOefqtP5LnNppmzMhA6qfcCxVWXwjiPU9zDraAh4LDQh_9PeDDPYgpycfPSVWM9SOqNnxaq_yLP5N4vAhTPgPP_HkVstu4y0)

Overview
- 4 VMs inside a single VPC/Subnet (e.g., 10.0.1.0/24). Example IPs: VM1 10.0.1.10, VM2 10.0.1.11, VM3 10.0.1.12, VM4 10.0.1.13.
- Admin access: SSH to each VM (key-only). Optional HTTP access to VM3:8080 for health.

Components by VM (per diagram)
- VM1 kafka-zk: Kafka 3.7.0 on 9092; ZooKeeper 3.9.2 on 2181 (localhost). UFW mirrors SGs.
- VM2 mongodb: MongoDB 7.0 on 27017; Collections: gpu_metrics, token_usage.
- VM3 processor: Docker + FastAPI on 8080; reads GPU metrics from NVML (nvidia-ml-py3), nvidia-smi parser, or gpu_seed.json fallback; writes gpu_metrics and token_usage (tokens, tps, cost_per_token) to MongoDB.
- VM4 producers: Docker; 1–2 producers publishing token events to Kafka.

Topics & Partitions (per hardware diagram)
- Kafka topic: tokens with 12 partitions (p0…p11).
- Consumer group: replicas ≤ partitions; Kafka assigns partitions to consumer replicas.

Sizing & Scaling (per hardware diagram)
- Suggested instances/resources:
  - VM1 Kafka (KRaft/ZK): t3.small or t4g.small; RAM 2 GB min (4–8 GB prod); Disk ≈20 GB gp3 SSD.
  - VM2 MongoDB 7.x: t3.small or t4g.small; RAM 2 GB min (4+ GB recommended); Disk ≈30 GB gp3 SSD; bind to private IP; enable auth.
  - VM3 Processor: t3.micro or t4g.micro; RAM ≈1 GB; Disk ≈10 GB gp3 SSD; scale replicas based on lag/CPU.
  - VM4 Producers: t3.micro or t4g.micro; RAM ≈1 GB; Disk ≈10 GB gp3 SSD.
- Partitioning guidance: start with 12 partitions; increase if replicas hit ceiling and lag grows.
- Throughput math: consumers needed C = ceil(P * t_proc * S) where P=msgs/s, t_proc=sec/msg, S=1.2–1.5.
- DB headroom: P * w ≤ W * H (w=writes/msg, W=db writes/s, H≈0.7).
- Autoscaling signals:
  - Processor: scale out if group lag > P·120s for 5–10m or CPU>70%; scale in when lag≈0 for 15m and CPU<40%.
  - MongoDB: alert/scale when p95 write latency > 20–30ms or CPU>70%.

Processor HTTP & Env
- Endpoints: /health; optional /gpu/info.
- Env: PRICE_PER_HOUR_USD controls cost_per_token computation.

Connectivity & Ports
- VM4 → VM1: Kafka 9092 (produce).
- VM3 → VM1: Kafka 9092 (consume).
- VM3 → VM2: MongoDB 27017 (writes).
- Admin → all VMs: SSH 22 (key-only).
- Admin → VM3: HTTP 8080 (optional).

Security Groups (per diagram)
- VM1 (Kafka): allow 9092 from sg-processor and sg-producers only; mirror with UFW.
- VM2 (MongoDB): allow 27017 from sg-processor only.
- VM3 (Processor): allow 8080 from Admin IP only.
- No additional network ports required for GPU metrics (NVML/SMI/seed are local).

GPU Metrics Sources
- Preferred: NVML (nvidia-ml-py3) and nvidia-smi parser.
- Fallback: local gpu_seed.json file when no GPU present.

Replication (high-level)
- Provision 4 VMs (≈2 vCPU, 4 GB) in one subnet.
- Secure SSH (PasswordAuthentication no; key-only); mirror SGs with UFW on-box.
- Install Kafka on VM1 (with ZooKeeper local-only if used), MongoDB on VM2, Docker on VM3/VM4.
- Run processor container on VM3 (Kafka consumer; reads NVML/SMI/seed; computes cost_per_token; writes to MongoDB collections).
- Run 1–2 producer containers on VM4 (publish to tokens topic).
- Verify: produce → tokens (12 partitions) → processor group → MongoDB documents (gpu_metrics, token_usage).
