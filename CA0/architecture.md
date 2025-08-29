# CA0 – Manual Deployment on 4 VMs with GPU Cost/Token Use Case

Context
- Manually provision 3–4 VMs, install services, wire the pipeline, secure ports, and validate end-to-end.
- Chosen cloud: AWS (t3a.medium x4) or equivalent VMs. Local setups acceptable; topology remains identical.

Diagram (PlantUML)
![PlantUML](https://www.plantuml.com/plantuml/svg/XLDXRzis4FtENt7BbzbOPLkoiIJ-C3HptCJet0bHacA30OEMQ5iJnHD8AfutzB_lI2cHWxKD35WYx-cHz-wzzyPoRUjIiX_iNfG2dlADvieocrifO7OrWW0cSFKvWSUbWTv7lYqu_0HBL3kaPwmn5SQWRjwpEXNQz6bn4p_038qTtcCX56Eco5N5DI_1x7c6XrpjOCkb4IUL4XMcUusb0AlhqqgAPOLAA9lOenIWHMgvsad164yjQZYxoifSGUyFh3KiuluPS0D-Zp65cI00TL2RG71ZW_0C_cK0MsAcocCyWt0qyBzX-FDA9VL62TliXRGNJJmTuVnd00tZupA4miaH_5EiL8iEHolLQ3GUd0z6CBqSNKOhzIVYHo4geMdxSX31D0elGkX9JBdSaqhDXOdn5Ny4fPCvstJquKfvwQz_1KyVdO_2yvMQePIaIOxAJ65NrUjIM9sdvXrO9_-wDdmdsZEYLsUCeNeUONSAtVWQqqAugNuWnQxY1KmlHXVKd9jhIpw5Ju_BtuR9SZ5CXCXQ-l4h-WbKpwxewCSdz547Q0acHF25VM7iHsYcobDtFzOiWk0NSCfF8Kbk8OgWLuWZe9B7_Yj4z2PY_2PYyXt4OF3CSNj_7uCJ1th3lU3Ixjy1LcuMNCAGXZ7CrHRxhfyuhuJCbO13hYa0p1tHDTJunXa6UgqeVOAClm59KPcwx21jqy_syCw0ta7drWS6TMRy9Kuc25nba295WgmPUAkmbwZ1cHllIlNKKvxbF2XbK1t7ZLDTvHJPGaoP4vuYQuHkW6GEbd7BDzoG7vmpZH3Pu2-3Yf3U_x3DfMZHy_ary_sGlFuGc7PQQi6pbo8HVxj6D5JSSYatF2swOgUIb-KqAL-jduI7RkjNBb8L_JdLrgJQskzwOHEHrlJP4RXIQBbF8rFevCztUmkuzGbFRgP0DyD3CyUjnf85O7R1In1VbaqksCE7pr3cMgCcYMwOK1auMlO_ygWZR-R_DNPlu--GZ3iIRslFqKPn4REvUff2VBUOpTVn_6vz-_l3tVeXkMQV4CJVLdDGmXvG5r2XjWQsg9tZklFUqrjToly0)

```plantuml
@startuml
title CA0 - 4 AWS VMs (Kafka + Mongo + Processor + Producers) + GPU Cost/Token

skinparam shadowing false
skinparam monochrome true
skinparam componentStyle rectangle

actor "Admin (Your IP)" as Admin

node "AWS us-east-1" {
  frame "VPC 10.0.0.0/16\nSubnet 10.0.1.0/24" as VPC {
    node "VM1 kafka-zk\n10.0.1.10\nKafka 3.7.0 :9092\nZooKeeper 3.9.2 :2181 (localhost)" as VM1
    node "VM2 mongodb\n10.0.1.11\nMongoDB 7.0 :27017\nCollections: gpu_metrics, token_usage" as VM2
    node "VM3 processor\n10.0.1.12\nDocker + FastAPI :8080\nGPU metrics: NVML/SMI/Seed" as VM3
    node "VM4 producers\n10.0.1.13\nDocker + 2 producers" as VM4
  }
}

' Admin access
Admin --> VM1 : SSH 22 (key only)
Admin --> VM2 : SSH 22 (key only)
Admin --> VM3 : SSH 22 (key only)
Admin --> VM4 : SSH 22 (key only)
Admin ..> VM3 : HTTP 8080 (/health, optional /gpu/info)

' Pipeline wiring
VM4 --> VM1 : Kafka 9092 (produce)
VM3 --> VM1 : Kafka 9092 (consume)
VM3 --> VM2 : MongoDB 27017 (write records)

' GPU metrics and cost-per-token
component "NVML\n(nvidia-ml-py3)" as NVML
component "nvidia-smi\n(parser)" as SMI
database "gpu_seed.json\n(local file)" as SEED

VM3 ..> NVML : optional read
VM3 ..> SMI : optional read
VM3 ..> SEED : fallback read
VM3 --> VM2 : write gpu_metrics
VM3 --> VM2 : write token_usage\n(tokens, tps, cost_per_token)

' Security annotations
note right of VM1
SG: allow 9092 from
- sg-processor
- sg-producers
UFW mirrors SG
end note

note right of VM2
SG: allow 27017 from
- sg-processor only
end note

note right of VM3
SG: allow 8080 from Admin IP
Env: PRICE_PER_HOUR_USD
No extra network ports for GPU
end note

@enduml
```

Replication (high-level)
- Provision 4 VMs (≈2 vCPU, 4 GB) in one subnet.
- Secure SSH (PasswordAuthentication no; key-only), ufw mirror SGs.
- Install Kafka+ZooKeeper on VM1 (systemd), MongoDB on VM2, Docker on VM3/VM4.
- Run processor container on VM3 (Kafka consumer, reads GPU metrics or seed JSON, computes cost_per_token, writes to MongoDB).
- Run 1–2 producer containers on VM4 (publish token events to Kafka).
- Verify: produce → topic → processor → MongoDB documents (gpu_metrics, token_usage).
