# CA1 – Infrastructure as Code (IaC) Rebuild of CA0

Context
- Idempotent provisioning and configuration via code with parameters and secret management.

Diagram (PlantUML)
```plantuml
@startuml
title CA1 - IaC-Driven Deployment (Same Topology, Automated)

skinparam shadowing false
skinparam monochrome true
skinparam componentStyle rectangle

actor "Developer" as Dev
component "CI Runner / Local CLI\n(make deploy/destroy)" as CI

package "IaC Code" {
  component "Terraform\n(VPC, SG, VMs)" as TF
  component "Ansible\n(Kafka, Mongo, Proc, Producers)" as ANS
  collections "Vars/Secrets" as VARS
}

node "Any Cloud (Region/Subnet)" {
  node "VM1 kafka-zk\n:9092" as VM1
  node "VM2 mongodb\n:27017" as VM2
  node "VM3 processor\n:8080\nGPU metrics: NVML/SMI/Seed" as VM3
  node "VM4 producers" as VM4
}

Dev --> CI : trigger deploy/destroy
CI --> TF : terraform apply/destroy
TF --> VM1
TF --> VM2
TF --> VM3
TF --> VM4

CI --> ANS : ansible-playbook
ANS --> VM1 : install Kafka+ZK
ANS --> VM2 : install MongoDB
ANS --> VM3 : deploy processor container
ANS --> VM4 : run 1–2 producers

note bottom
New in CA1:
- Idempotent infra + config as code
- Parameterized sizes, images, topics
- Secrets via vault/SM
end note

@enduml
```

Replication (high-level)
- make deploy → make test → make destroy.