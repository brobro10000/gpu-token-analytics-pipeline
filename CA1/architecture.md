# CA1 – Infrastructure as Code (IaC) Rebuild of CA0

Context
- Recreate CA0 via code (Terraform/Ansible/etc.), idempotent, parameterized, secure secrets, and one-command deploy/destroy.
- Pipeline unchanged: Producers → Kafka → Processor → MongoDB (same as CA0), but fully automated.

Diagram (PlantUML)
![PlantUML](https://www.plantuml.com/plantuml/svg/LLFTRXez4BttKyp7nITG8110oiz55KhKAgfeesp4LM-6tO6uUEsjFIQYLQK-H9-mJz8nBDdDrNfypioUEPwv3OoUOsdKV_nC9S5EhpnQLgpP4Cnd5p20Uvp3BB8haQc0vI90zucynxNp9Pp1p0QzCjI3lx__m3sJHzREmjgxKWgCb0fRRIlqM49uniAzQBk1DPf0BQHqrkNFaaB0FhQHt9MLisGvuxr8yfGpseqXfJ1dvw5pHpiohYBV0GmWaQemt-A6e9EKprr17VYfeAa4dLVzNsrt-J3lG_Qndphh7MeyVNZBhZiKxhqDZCR0_rBMhlKcUZgcp3vdRtCooZrnW0LQaUBJVp0Q7cQBOqAsEF2DeJpP5Q2pH1-4vcaZSH-2_a6X3-mgdQSlRcfrozbZfdufPQKnwCoDYmLq7mzPmookB77lsE-Hi5nSm1RNMpmaIzH2nidtZIjMDJPkOHEelCif1EThTD92fmajOau-rEWqQHBtOJ1u9mx23V3ha61LcVsmeC3UxPM0YIDIckEuEKwQuxIfA0PBIJo-nA0ok5yvjrLoVIeciAwVvrFg5xetrwFhSQ_56RSuYzJvtNjXZIz75vTjsaHe1LN6xU7Xv87mhaPNepPjAZGVhN1g9vJA5d1-VXAhxJTvN90vA89AhoPOigOv2qyfATHgeROL3je5cxImtDaGopRMjFNYDHCSUqcp8S7ACRjIfIL-fEzHUoh9ShXHij85oQIoXEc7EnraUD9QdW4JUjbHAwI7j7_4v6KI2zYXroZU1q5EmxtJA8CyF4osN7-9N4Mv5f4b-hriIIZTbgHcO4MsW2HBgLivnjBy0m00)
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
