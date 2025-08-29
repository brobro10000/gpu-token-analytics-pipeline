# CA4 – Multi-Hybrid Cloud (Final)

Context
- Extend CA2 across two sites/clouds with secure connectivity and replication; prove resilience and document a runbook.

Diagram (PlantUML)
```plantuml
@startuml
title CA4 - Multi/Hybrid: Two Sites + Secure Connectivity + Replication — Iteration from CA3

skinparam shadowing false
skinparam monochrome true
skinparam componentStyle rectangle

actor "Operator" as Op

node "Site A (Cluster/Region A)" {
  frame "Namespace: pipeline" {
    component "Kafka-A (KRaft) SS" as KafkaA
    component "Mongo-A SS" as MongoA
    component "Processor-A Deploy" as ProcA
    component "Producers-A Job" as ProdA
  }
}

node "Site B (Cluster/Region B)" {
  frame "Namespace: pipeline" {
    component "Kafka-B (KRaft) SS" as KafkaB
    component "Mongo-B SS" as MongoB
    component "Processor-B Deploy" as ProcB
    component "Producers-B Job" as ProdB
  }
}

cloud "Secure Connectivity\n(VPN/Mesh/Bastion)" as Conn
KafkaA <--> Conn : MirrorMaker2
Conn <--> KafkaB : cross-region topics
MongoA <--> Conn : replica set or
Conn <--> MongoB : backup/restore

Op --> ProcA : primary ops
Op --> ProcB : failover ops
ProdA --> KafkaA : produce
ProcA --> KafkaA : consume
ProcA --> MongoA : write
ProdB --> KafkaB : produce
ProcB --> KafkaB : consume
ProcB --> MongoB : write

note bottom
CA4 Requirements:
- Two sites with secure connectivity
- Cross-region Kafka replication (MM2)
- DB strategy (replica set or backup/restore)
- Failover drill & runbook documentation
end note

@enduml
```

Replication (high-level)
- Establish connectivity, deploy to both sites, configure MM2 and DB strategy, run failover drill and document recovery.