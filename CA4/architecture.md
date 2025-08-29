# CA4 – Multi-Site Connectivity & Advanced Networking

Context
- Scale to multiple regions with service mesh, cross-region replication, and disaster recovery.

Diagram (PlantUML)
```plantuml
@startuml
title CA4 - Multi-Site with Service Mesh & Cross-Region Replication

skinparam shadowing false
skinparam monochrome true
skinparam componentStyle rectangle

actor "Global User" as User

cloud "Region A (Primary)" {
  node "K8s Cluster A" {
    frame "Service Mesh (Istio)" {
      component "Kafka A\nLeader" as KafkaA
      component "MongoDB A\nPrimary" as MongoA
      component "Processor A\nActive" as ProcA
      component "Producers A" as ProdA
    }
  }
}

cloud "Region B (DR)" {
  node "K8s Cluster B" {
    frame "Service Mesh (Istio)" {
      component "Kafka B\nFollower" as KafkaB
      component "MongoDB B\nSecondary" as MongoB
      component "Processor B\nStandby" as ProcB
      component "Producers B" as ProdB
    }
  }
}

component "Global Load Balancer" as GLB
component "Cross-Region VPN/TGW" as VPN

User --> GLB
GLB --> ProcA : primary traffic
GLB --> ProcB : failover traffic

KafkaA <--> KafkaB : cross-region replication
MongoA <--> MongoB : replica set sync

note bottom
New in CA4:
- Multi-region deployment
- Service mesh (Istio/Linkerd)
- Cross-region data replication
- Global load balancing & failover
end note

@enduml
```

Replication (high-level)
- Deploy multi-region clusters; configure service mesh; test cross-region failover.