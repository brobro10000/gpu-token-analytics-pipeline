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
component "MirrorMaker2\n(Kafka Replication)" as MM2
component "DB Replication\n(or Backup/Restore)" as DBRep

KafkaA <--> Conn
KafkaB <--> Conn
Conn --> MM2 : cross-site replication
MM2 --> KafkaA
MM2 --> KafkaB

MongoA <--> DBRep : replica set / backup
MongoB <--> DBRep

ProdA --> KafkaA : produce
ProcA --> KafkaA : consume
ProcA --> MongoA : write

ProdB --> KafkaB : produce
ProcB --> KafkaB : consume
ProcB --> MongoB : write

note bottom
CA4 Requirements:
- Two sites with secure connectivity
- Kafka replication via MirrorMaker2
- DB replication or backup/restore
- Failover drill + documented runbook
end note

@enduml
```

Replication (high-level)
- Establish connectivity, deploy to both sites, configure MM2 and DB strategy, run failover drill and document recovery.