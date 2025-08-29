# CA2 – PaaS Orchestration (Kubernetes or Swarm)

Context
- Run the CA0 pipeline on an orchestrator using declarative manifests. Example: Kubernetes with KRaft Kafka.

Diagram (PlantUML)
![PlantUML](https://www.plantuml.com/plantuml/svg/VLFDJXi_4B_xAURFuQz49Kh81KZLYZOvb5P0H51FICZnpcwiU3skFHk4AgG-H9-mJzBnRb92LFNYjVtxsFdmN2JMaPlQgVzuXJN2nYwZzgpOiaEOVXZ306wYMM7Yg1aBcDk0pdg4tfTcYT4ZO-h3hny_uP9HA9Oyb95gqPuebTRM1nrr3Mcb2tgqle9IkuHxI4sUp4ea21oRVSHG7SYZvmK_EOI8XhMl72gb3LE4enbkq570U0GwWPoKybGW7Bt41bFN9CwCxmgW55k1hsLDGHkSGDZcq-7myaynqULQIvwtkkJ-lL-mPYmRjq26Dp3_EfKhZ1kRNTQPEZaVdO_RI5hbeTqL-Ofc7_zjL6VIP7mwEZbjdLhHeTCyai6KADxx6GP7JtM-xaNPMwFJkt5_pp7io9EpqTceDStwltWMZS6OxlrdMWwdaV8NUjSGg4ZzdQuur4t9bxQwqY4D5sWYiXZqq6-EGGv5EWQcOCtMO5fMedzMhnmkVHKbmE4r5JYdoAAdaD-HTZ1SeNQywjHRedfMIbeDWy7xtHLCuDFTtNn7Xpy6VPLZRgbTDwKUNQBGTYl3vXLioAUcFeIxFWZy62qZLA5vg96ZDMs2Q_GFJT8LvkSdy9AOgLPvUcxnMsCZvWQbYHh038tJUKms2BNsjiJ42SYx9m6tFHDFUHIoljJs6BR55TRDhZYsI_ujRBIpXMQ4_u5HHvaphz0Na8DH5xAJ0VyD)
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
