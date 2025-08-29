# CA1 – Infrastructure as Code (IaC) Rebuild of CA0

Context
- Recreate CA0 via code (Terraform/Ansible/etc.), idempotent, parameterized, secure secrets, and one-command deploy/destroy.
- Pipeline unchanged: Producers → Kafka → Processor → MongoDB (same as CA0), but fully automated.

Diagram (PlantUML)
```plantuml
@startuml
title CA1 - IaC Automated VMs (Terraform + Ansible) — Iteration from CA0

skinparam shadowing false
skinparam monochrome true
skinparam componentStyle rectangle

actor "Developer" as Dev
package "IaC Code" {
  component "Terraform\n(VPC, SG, VMs)" as TF
  component "Ansible\n(Install & Configure)" as ANS
  component "Secrets Manager\n(Vault/SM)" as SM
  collections "Vars\n(region, sizes, topics, tags)" as VARS
}

node "Cloud (Region/Subnet)" {
  node "VM1 kafka" as VM1
  node "VM2 mongodb" as VM2
  node "VM3 processor" as VM3
  node "VM4 producers" as VM4
}

Dev --> TF : terraform apply/destroy
TF --> VM1
TF --> VM2
TF --> VM3
TF --> VM4

Dev --> ANS : ansible-playbook
ANS --> VM1 : install Kafka (:9092)
ANS --> VM2 : install MongoDB (:27017)
ANS --> VM3 : deploy Processor (:8080)
ANS --> VM4 : run Producers

SM ..> ANS : inject creds
VARS ..> TF
VARS ..> ANS

VM4 --> VM1 : produce :9092
VM3 --> VM1 : consume :9092
VM3 --> VM2 : write :27017

note bottom
CA1 Requirements:
- Idempotent provisioning + teardown
- Parameterized variables
- Secrets via SM/Vault
- Outputs summary & smoke test
end note

@enduml
```

Replication (high-level)
- make deploy → provisions VMs and installs components; make test → smoke test; make destroy → teardown.