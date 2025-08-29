# CA4 – Multi-Hybrid Cloud (Final)

Context
- Extend CA2 across two sites/clouds with secure connectivity and replication; prove resilience and document a runbook.

Diagram (PlantUML)
![PlantUML](https://www.plantuml.com/plantuml/svg/dLJ1RXfD3BxFK_Zdy0jK8QIq9rHLOHDLRIEI2AgUUXbc3OoO7KyztY1KHUf3z0dx99sPLTg5a4ilYFNt-RC_UzUNKJHBspZrdsonGNYmAzPUb5Xn25UpDp26UUl4JZuSLcphANpU4oojO8HNi4JJSgAHzsZ4FbWvfEW2WxD6YoKFltxyX8-2t3sjcPea-bgfkBC-QDODnAskQM_z1jRQHUmX3NaosvI28Dps4KDD88zUbd9m29oAQxzng9GsGWo3kv1B4Wz0HxWBIdcg4GQvRvZ1yCgrKP0d2zpajcQZ0NnN0EkadLYtwJS6RN0AmGPqrcE7mz_2CBZHwvqU9x6RXLxB29RBKgo4PwVaEVaD9N97WlBuZ7JFP316uaIynk3eKCWvV8vRjmOv9kudMZqHwqnyL8z7XgjdXgj_DroTDLoTDrmT6QvUDboT6gvUDbmT6QwU31j7RGs3Cw_aLp_ySdyxcMFSJYeTyviuAlcPfBg5mTln-5q9m1JcbfbuhdV85wh42jevJRXXYd7CtIo5WZLH5OV7Cjnz1n1HWBWdLBXPQANDhWqJnYZ4gDHTW8Ht6qzmODjeFW25s8TovbfRHm_81IkBXpyjbjHkN1ao9v0X7zkc3tMz9sZFLWfGLz1pV2nt0lNbAZYoryafJuAm8X5gLBue2_pMMiO6lSIf6fUB4ij5sLlPGkmsQ7eRJAIh_inBSU3UdHdEvnUZHBkk80fhmSq1XiSBE9bsPhz_ccBDrZdu7xZrAw8Tr6JQt5yHL-Xho2RKPVhNDkut)
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
