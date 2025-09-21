# Conversation Summary — CA1

## Timeline of Milestones

| Date (UTC) | Milestone / Topic               | Key Decisions & Outcomes                                                                                                                                                                                                           |
| ---------- | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2025-09-20 | CA1 high-level summary          | Defined CA1 as the Infrastructure-as-Code successor to CA0. Goal: move from manual VM provisioning to automated reproducible Terraform-managed infrastructure.                                                                     |
| 2025-09-21 | Initial CA1 PUML generation     | Generated draft versions of `ca1-architecture.puml`, `ca1-provisioning-sequence.puml`, and `ca1-readme.md`. These captured a Terraform-driven design with modules for VPC, SGs, and EC2 instances, plus bootstrap with cloud-init. |
| 2025-09-21 | Updating PUML with tech details | Integrated CA0 docs into CA1 diagrams. Annotated each VM stack: Kafka 3.7.0 (KRaft), MongoDB 7.0, FastAPI/Uvicorn processor, Python confluent-kafka producers. Added Docker Compose bootstrap.                                     |
| 2025-09-21 | Syntax correction in PUML       | Fixed PlantUML issues: explicit aliases for SGs and modules, corrected stereotypes, fixed diagram references.                                                                                                                      |
| 2025-09-21 | Step-by-step guide              | Authored `CA1-step-by-step-guide.md` covering repo layout, Terraform modules, VPC/SG configs, EC2 templates, cloud-init YAML, Makefile helpers, and verification steps.                                                            |
| 2025-09-21 | AWS IAM/Terraform setup         | Clarified root is not allowed. Documented IAM user/SSO setup, permissions, CLI config, and STS validation.                                                                                                                         |
| 2025-09-21 | Running Terraform               | Confirmed Terraform must be run from `ca1/terraform`. Listed core commands: `init`, `plan`, `apply`.                                                                                                                               |
| 2025-09-21 | Terraform state management      | `.tfstate` excluded from Git. Suggested S3 + DynamoDB backend for collaboration.                                                                                                                                                   |
| 2025-09-22 | AMI lookup fix                  | Replaced brittle `aws_ami` filter with AWS SSM parameter for Ubuntu 24.04 LTS (amd64). Eliminated lookup errors.                                                                                                                   |
| 2025-09-22 | Instance type alignment         | Chose minimum x86 types: Kafka/Mongo → `t3.small`, Processor/Producers → `t3.micro`. Avoided ARM (`t4g.*`).                                                                                                                        |
| 2025-09-22 | Terraform variable cleanup      | Fixed single-line variable errors; switched to multi-line blocks. Added float variable `price_per_hour_usd`.                                                                                                                       |
| 2025-09-22 | Wiring module inputs            | Passed `subnet_id` and `sg_ids` outputs from VPC/SG modules into `instances` module.                                                                                                                                               |
| 2025-09-22 | Private IP handling             | Selected dynamic AWS-assigned private IPs. Terraform injects discovered IPs into dependent VMs (Processor/Producers).                                                                                                              |
| 2025-09-22 | Makefile improvements           | Added `deploy` (init+plan+apply) and `down` (destroy). Split `clean` vs `nuke`. Auto-injected `my_ip_cidr`. Centralized workflow.                                                                                                  |
| 2025-09-22 | Tooling & linting               | Integrated `terraform fmt`, `validate`, `tflint` (v0.54+ `call_module_type`), and recommended `checkov`/`tfsec`. Added pre-commit hooks.                                                                                           |
| 2025-09-22 | Outputs & data sources          | Added root outputs: account\_id, arn, region, vpc\_id, subnet\_id, sg\_ids, instance\_private\_ips, instance\_public\_ips.                                                                                                         |

---

## Meta

* User: Hamzah (@hamzah)
* Context: Transition from CA0 (manual multi-VM) to CA1 (Terraform + Docker-Compose IaC).
* Artifacts: PUML diagrams, provisioning sequence, README, step-by-step guide, Terraform modules, Makefile, TFLint config, outputs.

---

## Requests

* Define CA1 scope vs CA0.
* Generate and refine CA1 diagrams.
* Debug PlantUML syntax errors.
* Write Terraform setup guide.
* Explain IAM setup, execution context, and state handling.
* Fix AMI lookup and align instance types.
* Wire missing module inputs.
* Add cost tracking variable.
* Improve Makefile workflows.
* Add linting and outputs.
* Produce up-to-date documentation.

---

## Decisions

* **CA1 mirrors CA0**: Same 4-VM pipeline; now managed with Terraform + cloud-init.
* **VM stacks**:

    * VM1: Kafka 3.7.0 (KRaft)
    * VM2: MongoDB 7.0.x
    * VM3: FastAPI 0.112 + Uvicorn 0.30
    * VM4: Python 3.12 + confluent-kafka 2.5
* **Bootstrap**: Cloud-init installs Docker + Compose; runs per-VM services.
* **AMI**: Ubuntu 24.04 LTS (amd64) via AWS SSM parameter.
* **Instance types**: Kafka/Mongo = `t3.small`; Processor/Producers = `t3.micro`.
* **Private IPs**: Dynamic; Terraform references propagate them.
* **Modules**: Root (`main.tf`, `variables.tf`, `outputs.tf`) plus submodules: VPC, SGs, Instances.
* **State**: Local for dev; S3+DynamoDB for team.
* **Repo layout**: Terraform under `ca1/terraform/`; diagrams in `/diagrams`; docs in `/docs`.
* **Makefile**: Central workflow with `deploy`, `down`, `clean`, `nuke`.
* **Tooling**: `fmt`, `validate`, `tflint`, `checkov`/`tfsec`, pre-commit hooks.

---

## Tradeoffs

* Terraform-only vs Ansible: Chose Terraform + cloud-init for simplicity.
* Local vs remote state: Remote required for teams.
* Public vs private subnets: Public used now; NAT/bastion deferred.
* Static vs dynamic IPs: Dynamic reduces drift.
* Free Tier vs CA1 spec: Picked t3 family (x86) over Free Tier t2.

---

## AI Assistance

* Generated and fixed PUML diagrams.
* Authored README and setup guide.
* Guided IAM user creation and CLI config.
* Debugged AMI lookup and switched to SSM.
* Recommended x86 instance types.
* Added float variable support.
* Wired missing module inputs.
* Enhanced Makefile workflows.
* Added linting and pre-commit tooling.
* Added outputs for metadata and IPs.

---

## Highlights

* Terraform modules → AWS resources → VMs → Docker services.
* Provisioning: Terraform → EC2 → user-data → Docker Compose → validation.
* SG-to-SG rules with least privilege.
* Dynamic private IP wiring to Processor/Producers.
* IAM enforced; root disallowed.
* `.tfstate` excluded from Git.
* Makefile centralizes deploy/destroy.
* Outputs include metadata and IPs.

---

## Next Steps

* Implement per-VM cloud-init templates to launch Kafka, Mongo, Processor, Producers.
* Configure remote S3 + DynamoDB backend.
* Run `make deploy` and validate E2E pipeline (Producers → Kafka → Processor → Mongo).
* Add troubleshooting and verification guide.
* Integrate linting/security scans into CI/CD.

---

## Execution Guide

**Directory**: run from `ca1/terraform`

**Makefile helpers**:

```bash
make deploy   # init + plan (auto my_ip_cidr) + apply
make outputs  # show outputs
make down     # terraform destroy
make fmt      # autoformat
make validate # schema validation
make lint-init && make lint  # tflint
```

**Raw Terraform**:

```bash
terraform init
terraform plan -out=tfplan -var="my_ip_cidr=$(curl -s ifconfig.me)/32"
terraform apply tfplan
terraform output
```

---

**Status:** CA1 is defined and modules ready. AMI, instance types, variables, Makefile, and outputs are in place. Next: cloud-init templates and full pipeline validation.
