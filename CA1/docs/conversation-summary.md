# Conversation Summary — CA1

## Timeline of Milestones

| Date (UTC) | Milestone / Topic               | Key Decisions & Outcomes                                                                                                                                                                                                                             |
| ---------- | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2025-09-20 | CA1 high-level summary          | Defined CA1 as the Infrastructure-as-Code successor to CA0. Goal: move from manual VM provisioning to automated reproducible Terraform-managed infrastructure.                                                                                       |
| 2025-09-21 | Initial CA1 PUML generation     | Generated draft versions of `ca1-architecture.puml`, `ca1-provisioning-sequence.puml`, and `ca1-readme.md`. These captured a basic Terraform-driven design with modules for VPC, security groups, and EC2 instances, plus bootstrap with user-data.  |
| 2025-09-21 | Updating PUML with tech details | Integrated CA0 documentation into CA1 diagrams. Explicitly annotated each VM with its technology stack: Kafka 3.7.0 (KRaft), MongoDB 7.0, FastAPI/Uvicorn processor, Python confluent-kafka producers. Added Docker Compose as bootstrap mechanism.  |
| 2025-09-21 | Syntax correction in PUML       | Fixed PlantUML issues: introduced explicit aliases for security groups and Terraform modules, adjusted stereotype placement (`<<docker>>`, `<<tf>>`), ensured valid references in diagram relationships.                                             |
| 2025-09-21 | Step-by-step guide              | Authored a detailed `CA1-step-by-step-guide.md` outlining repo structure, Terraform root and module layout, VPC and SG configs, EC2 instance templates, cloud-init bootstrap YAML files per VM, Makefile helpers, and verification steps.            |
| 2025-09-21 | AWS IAM/Terraform setup         | Clarified that root cannot be used. Explained why IAM user or SSO profile is required. Provided a full guide on creating an IAM user, attaching permissions, generating keys, configuring AWS CLI, and verifying with `aws sts get-caller-identity`. |
| 2025-09-21 | Running Terraform               | Explained that Terraform must always be run from inside the folder containing `.tf` files (e.g., `ca1/terraform`), otherwise `terraform init` will not find configuration.                                                                           |
| 2025-09-21 | Terraform state management      | Highlighted that `terraform.tfstate` must never be committed to Git. Added `.gitignore` patterns, explained sensitive data risks, and suggested using S3 + DynamoDB remote state for collaboration.                                                  |
| 2025-09-21 | Conversation summary planning   | Built a CA1-focused conversation summary to complement the CA0 log. Consolidated milestones, decisions, tradeoffs, and AI assistance into a structured format for repository documentation.                                                          |

---

## Meta

* User: Hamzah (@hamzah)
* Context: Transition from CA0 (manual multi-VM setup) to CA1 (Terraform + Docker-Compose IaC).
* Artifacts produced: PUML architecture diagrams, provisioning sequence diagram, CA1 README, detailed step-by-step guide with Terraform + cloud-init, conversation summary logs.

---

## Requests

* Define CA1 scope and relationship to CA0.
* Generate initial CA1 diagrams (architecture + provisioning).
* Update diagrams to include actual technologies and Docker bootstrap.
* Debug PlantUML syntax errors.
* Write a structured guide to set up CA1 Terraform project.
* Explain AWS authentication best practices (root vs IAM).
* Clarify Terraform execution context and state management.
* Produce a detailed summary for documentation and GitHub.

---

## Decisions

* **CA1 vs CA0**: CA1 directly mirrors CA0’s 4-VM pipeline but moves provisioning and configuration into Terraform, maintaining feature parity while ensuring reproducibility.
* **Per-VM technology stack**:

    * VM1: Kafka 3.7.0 (KRaft, no ZooKeeper)
    * VM2: MongoDB 7.0.x with `gpu_metrics` and `token_usage` collections
    * VM3: FastAPI 0.112 + Uvicorn 0.30 with `/health` endpoint and environment-driven config
    * VM4: Python 3.12 + confluent-kafka 2.5 producers emitting GPU and token metrics
* **Bootstrap strategy**: Cloud-init installs Docker + Compose, fetches repo folders, brings services up with `docker compose`, creates Kafka topics, seeds Mongo, and writes `.env` for processor and producers.
* **Terraform structure**: Root-level project with submodules (`vpc`, `security_groups`, `instances`), templated user-data files, outputs for IPs and URIs.
* **Repo layout**: Keep `.tf` files under `ca1/terraform/`; diagrams under `/diagrams`; docs under `/docs`.
* **State management**: Exclude `.tfstate` files from Git, prefer S3 + DynamoDB for team state storage.
* **IAM setup**: Always use IAM user or SSO; root is prohibited for Terraform workflows.

---

## Tradeoffs

* **Terraform-only vs Terraform + Ansible**: Chose Terraform-only with cloud-init user-data for bootstrap, reducing complexity but limiting fine-grained config management.
* **Local vs remote state**: Local acceptable for individual testing, but remote (S3+DynamoDB) required for collaboration.
* **Private subnet vs public subnet**: CA1 diagrams assume private-only subnets. Public reachability requires NAT or bastion host, which was deferred for now.
* **KRaft vs ZooKeeper**: Retained KRaft mode to simplify Kafka setup and align with CA0.

---

## AI Assistance

* Authored initial CA1 PlantUML diagrams (`architecture.puml`, `provisioning-sequence.puml`).
* Expanded diagrams with actual software versions, ports, topics, and Docker bootstrap flows.
* Corrected PlantUML syntax issues with explicit aliases and stereotypes.
* Produced `ca1-readme.md` with repo layout, variable definitions, and usage commands.
* Authored comprehensive `CA1-step-by-step-guide.md` covering Terraform setup, modules, cloud-init templates, and Makefile.
* Provided detailed AWS IAM setup guidance, including creating users, attaching permissions, configuring CLI, and validating with STS.
* Explained Terraform workflow best practices, including execution directory, `.tfstate` handling, `.gitignore` rules, and remote backends.
* Consolidated discussions into a formal conversation summary suitable for GitHub documentation.

---

## Highlights

* **Architecture captured**: Clear mapping of Terraform modules → AWS resources → VMs → Docker services.
* **Provisioning sequence**: Step-by-step Terraform → EC2 → user-data → Docker Compose → validation flow.
* **Security groups clarified**: SG-to-SG rules for Kafka, Mongo, and Processor, with SSH and `/health` restricted to admin IP.
* **Cloud-init templates**: Defined per VM (Kafka, Mongo, Processor, Producers) with Compose configs and `.env` injection.
* **IAM enforced**: Stressed that Terraform cannot and should not run under root; IAM user or SSO profile mandatory.
* **State hygiene**: Emphasized `.tfstate` is sensitive and must not be versioned; recommended remote state for teams.
* **Repo readiness**: Suggested clean repo layout with `/terraform`, `/diagrams`, `/docs`, `.gitignore`, and Makefile.

---

## Next Steps

* Implement Terraform modules in code, starting with VPC, subnet, and SGs.
* Add cloud-init templates per VM to bootstrap services on instance launch.
* Configure remote S3 + DynamoDB backend for Terraform state in shared environments.
* Validate full end-to-end pipeline with Terraform-managed infra, from producers through Kafka and processor to Mongo.
* Extend documentation with verification commands and troubleshooting.

---

**Status:** CA1 is defined, diagrams and guides produced, AWS authentication clarified, and Terraform best practices adopted. The foundation is laid for implementing the modules and validating the four-VM pipeline end-to-end with Infrastructure as Code.
