# CA2 – PaaS Orchestration (Kubernetes or Swarm)

Context
- Declarative manifests on a single Kubernetes cluster.

Diagram (PlantUML)
```plantuml
@startuml
title CA2 - Kubernetes Orchestration (Single Cluster)

skinparam shadowing false
skinparam monochrome true
skinparam componentStyle rectangle

actor "Developer" as Dev

node "Kubernetes Cluster" {
  frame "Namespace: pipeline" {
    component "Kafka (KRaft) StatefulSet\n1 broker + PVC\nService: kafka:9092" as Kafka
    component "MongoDB StatefulSet\nPVC\nService: mongo:27017" as Mongo
    component "Processor Deployment\nReplicas: 2\nService: processor:8080\nEnv: PRICE_PER_HOUR_USD" as Proc
    component "Producers Job/CronJob\nN pods" as Prod
    component "ConfigMaps/Secrets\nenv, creds, topics" as Cfg
  }
  component "Ingress/NodePort\n(optional /health)" as Ingress
}

Dev --> Ingress : HTTP /health (optional)
Prod --> Kafka : produce :9092
Proc --> Kafka : consume :9092
Proc --> Mongo : write gpu_metrics, token_usage

note bottom
New in CA2:
- Declarative manifests (Deployments, StatefulSets)
- Services, ConfigMaps, Secrets
- Optional ingress; storage via PVCs
end note

@enduml
```

Replication (high-level)
- Apply manifests; verify pods, services, PVCs; check Mongo docs.