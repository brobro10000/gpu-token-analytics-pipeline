# CA3 – Cloud-Native Ops (Observability, Autoscaling, Security, Resilience)

Context
- Enhance the CA2 cluster with ops features: logs/metrics, dashboards, autoscaling, network policies, disruption budgets, chaos drills.

Diagram (PlantUML)
![PlantUML](https://www.plantuml.com/plantuml/svg/RLJDRXCn4BxxAOOU4AXA8y4j1zHsY_ZfJmCHjroyzcHZnUjPndQh25NY8NX2deJncZOXz1BjpFTzu_dvbDEODAVSU_KYhR57k7Cjwv1KSiaZD6TlOGAtGvp1RHkHxtJhl4jRE8Qpd2WQxLte95gWoLo0tpz_mQU4h9EZ02kcNegyKIfkN1WqwnxYMbkwBxALzX7ta9u2cRL841BdVSHGFr30a1Pfwn4OJTAXywYKDeaOZcw7yYJn4UWe_IeLo28SNUOMEM3228tFCQ4GVYYGldGly8tyna4RdC7W1fHPiEAmUr6AwDL6ms8nrXw3GyOrXOuU6MDmo9Wp6OoH62vmyBHTXe_pinaqys_JB_EgAvHdP3ORv0YVgPqsJE6HQW-fDvZkYJTpyiuuZ2DFSXB_LvJiXOkSXtAYysmxJ9K-lpW_vCfTMU1fGs7bkcizL6QpweJvyEmcQTyepwnpNWuiPijn6Q9XFM24gMJOcLgy40v57rYlTD3BO7LSjwJPLcx97tAlQEEcxwykby5J5q5t7MCt-d6KN4coDhylQjQQ8hoY8RrUXetp7WQoqXXeQy7hXC5iH_b8L0zAbIF0PFAkMWB4GlLO1J3_08P2pFqEg1OHu9vTmbZo_PWl14dNhJmjHPKX7_5UyDqEL1bcNsh8UpG9okIgpdHoyeIkTFOfgceB0Mg7Ut7rhlXW1zQWkbC5IWWjfIGNAlyDN_5xTemzXXHdQWADVB3su_Dm36dDYB31BVmTHIZYUp2ZcpAZ1HqiMEmfH14cjC8uSBBKaHv4Agz5CHK6Ws2vdEWbS0ujqGRAky9LAELAa-fKldBl_m00)
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
