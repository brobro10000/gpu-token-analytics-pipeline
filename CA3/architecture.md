# CA3 – Cloud-Native Ops (Observability, Autoscaling, Security, Resilience)

Context
- Enhance CA2 with ops features and resilience tests.

Diagram (PlantUML)
```plantuml
@startuml
title CA3 - Cloud-Native Ops (Observability + Autoscaling + Security + Resilience)

skinparam shadowing false
skinparam monochrome true
skinparam componentStyle rectangle

actor "Developer" as Dev
actor "SRE" as SRE

node "Kubernetes Cluster" {
  frame "Namespace: pipeline" {
    component "Kafka SS + PVC" as Kafka
    component "MongoDB SS + PVC" as Mongo
    component "Processor Deployment\nHPA enabled\n/metrics endpoint" as Proc
    component "Producers Job" as Prod
  }
  
  frame "Namespace: monitoring" {
    component "Prometheus\nscrape /metrics" as Prom
    component "Grafana\ndashboards" as Graf
    component "Loki\nlogs aggregation" as Loki
  }
  
  frame "Security & Policies" {
    component "NetworkPolicies\nPodSecurityPolicies" as NetPol
    component "PodDisruptionBudgets" as PDB
  }
}

Dev --> Graf : view dashboards
SRE --> Graf : alerts & metrics
Proc --> Prom : expose /metrics
Prom --> Graf : query metrics
Kafka --> Loki : logs
Mongo --> Loki : logs
Proc --> Loki : logs

note bottom
New in CA3:
- Prometheus + Grafana + Loki
- HPA for processor scaling
- NetworkPolicies + PDBs
- Chaos engineering drills
end note

@enduml
```

Replication (high-level)
- Deploy monitoring stack; configure HPA and policies; run chaos experiments.