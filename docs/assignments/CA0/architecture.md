# CA0 – Manual Deployment on 4 VMs with GPU Cost/Token Use Case

Context
- Manually provision 3–4 VMs, install services, wire the pipeline, secure ports, and validate end-to-end.
- Chosen cloud: AWS (t3a.medium x4) or equivalent VMs. Local setups acceptable; topology remains identical.

Diagram (PlantUML)
```plantuml
@startuml
title CA0 - Manual Deployment on 4 VMs (Producers → Kafka → Processor → Mongo) + GPU Cost/Token

skinparam shadowing false
skinparam monochrome true
skinparam componentStyle rectangle

actor "Admin (Your IP)" as Admin

node "AWS (Region/Subnet)" {
  node "VM1 kafka-zk\nKafka 3.x :9092\nZooKeeper :2181 (localhost)" as VM1
  node "VM2 mongodb\nMongoDB 7.x :27017\nCollections: gpu_metrics, token_usage" as VM2
  node "VM3 processor\nDocker + FastAPI :8080\nGPU metrics: NVML/SMI/Seed" as VM3
  node "VM4 producers\nDocker + 1–2 Producers" as VM4
}

Admin --> VM1 : SSH 22 (keys only)
Admin --> VM2 : SSH 22 (keys only)
Admin --> VM3 : SSH 22 (keys only)\nHTTP 8080 (/health)
Admin --> VM4 : SSH 22 (keys only)

VM4 --> VM1 : Kafka produce :9092
VM3 --> VM1 : Kafka consume :9092
VM3 --> VM2 : Write docs :27017

component "NVML" as NVML
component "nvidia-smi" as SMI
VM3 ..> NVML : optional read
VM3 ..> SMI : optional read
VM3 --> VM2 : write gpu_metrics + token_usage\n(cost_per_token)

note right of VM1
Open: 22 from Admin\n9092 from Processor/Producers
end note

note right of VM2
Open: 22 from Admin\n27017 from Processor
end note

note right of VM3
Open: 22 from Admin\n8080 (optional) from Admin\nEnv: PRICE_PER_HOUR_USD
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