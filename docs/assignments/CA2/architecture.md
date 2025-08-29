# CA2 – PaaS Orchestration (Kubernetes or Swarm)

Context
- Run the CA0 pipeline on an orchestrator using declarative manifests. Example: Kubernetes with KRaft Kafka.

Diagram (PlantUML)
```plantuml
@startuml
title CA2 - Orchestrated Pipeline (Kubernetes) — Iteration from CA1

skinparam shadowing false
skinparam monochrome true
skinparam componentStyle rectangle

actor "Developer" as Dev

node "Kubernetes Cluster" {
  frame "Namespace: pipeline" {
    component "Kafka (KRaft)\nStatefulSet + PVC\nService: kafka:9092" as Kafka
    component "MongoDB\nStatefulSet + PVC\nService: mongo:27017" as Mongo
    component "Processor\nDeployment (replicas=2)\nService: processor:8080" as Proc
    component "Producers\nJob/CronJob (N pods)" as Prod
    component "ConfigMaps/Secrets\n(env, creds, topics)" as Cfg
  }
  component "Ingress/NodePort\n(optional /health)" as Ingress
}

Dev --> Ingress : HTTP /health (optional)
Prod --> Kafka : produce :9092
Proc --> Kafka : consume :9092
Proc --> Mongo : write gpu_metrics, token_usage

note bottom
CA2 Requirements:
- Declarative manifests only
- Services, PVCs, ConfigMaps, Secrets
- Optional ingress; validate & teardown
end note

@enduml
```

Replication (high-level)
- kubectl apply -f k8s/: namespace, Secrets/ConfigMaps, Kafka SS, Mongo SS, Processor Deployment, Producers Job.