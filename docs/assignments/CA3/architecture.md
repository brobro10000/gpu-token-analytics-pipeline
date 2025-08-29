# CA3 – Cloud-Native Ops (Observability, Autoscaling, Security, Resilience)

Context
- Enhance the CA2 cluster with ops features: logs/metrics, dashboards, autoscaling, network policies, disruption budgets, chaos drills.

Diagram (PlantUML)
```plantuml
@startuml
title CA3 - Ops: Observability + Autoscaling + Security — Iteration from CA2

skinparam shadowing false
skinparam monochrome true
skinparam componentStyle rectangle

actor "Operator" as Op

node "Kubernetes Cluster" {
  frame "Namespace: pipeline" {
    component "Kafka SS" as Kafka
    component "Mongo SS" as Mongo
    component "Processor Deploy\nHPA: CPU/QPS" as Proc
    component "Producers Job/Cron" as Prod
    component "NetworkPolicies" as NetPol
    component "PodDisruptionBudgets" as PDB
    component "Secrets/ConfigMaps" as Cfg
  }
  frame "Namespace: observability" {
    component "Prometheus\nscrapes /metrics" as Prom
    component "Grafana\ndashboards" as Graf
    component "Loki/ELK\nlogs aggregation" as Logs
  }
  component "Chaos (opt)\nkill pods / add latency" as Chaos
}

Prod --> Kafka : produce
Proc --> Kafka : consume
Proc --> Mongo : writes
Prom --> Proc : scrape /metrics
Graf --> Prom : dashboards
Logs --> Proc : collect logs
Chaos ..> Proc : faults
NetPol .. Kafka
NetPol .. Mongo
PDB .. Kafka
PDB .. Proc

note bottom
CA3 Requirements:
- Central logs + three key metrics
- HPA configured and demonstrated
- NetworkPolicies + PDBs
- Resilience drill & runbook entries
end note

@enduml
```

Replication (high-level)
- Deploy Prometheus/Grafana/Loki; expose /metrics; configure HPA, NetPols, PDBs; execute a chaos drill and document recovery.