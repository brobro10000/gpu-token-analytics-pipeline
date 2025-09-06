# CA0 — 4-VM Manual Deployment (cleaned)

This README is the concise, authoritative quick-start for CA0. It has been trimmed to reflect the current, in-repo documentation and Make-driven workflows. For full step-by-step instructions and background rationale see the linked files below.

Summary
- Pipeline: Producers → Kafka (VM1) → Processor (VM3) → MongoDB (VM2)
- Deployment model: 4 EC2 instances in a single VPC/subnet. Use private IPs for service-to-service traffic; public IPs only for SSH/management.
- Automation: use the root CA0/Makefile to bootstrap, sync, and run per-VM targets over SSH from your laptop.

Authoritative references (in-repo)
- AWS Console setup + exact bring-up commands: ./aws-vm-setup-instructions.md
- Architecture diagrams and details: ./docs/architecture.md
- Per-VM operational docs:
  - VM1 Kafka: ./vm1-kafka/README.md
  - VM2 MongoDB: ./vm2-mongo/README.md
  - VM3 Processor: ./vm3-processor/README.md
  - VM4 Producers: ./vm4-producers/README.md
- Root Makefile (remote orchestration): ../Makefile (root CA0/Makefile)

Quick prerequisites (on your laptop)
- SSH key with access to the instances (e.g., ~/.ssh/ca0)
- Clone this repo and set VM public/private IP variables in CA0/Makefile (or export as env when invoking make)
- Ensure make and rsync/ssh are available locally

Recommended fast-path (one-line intent)
1. Create VPC, subnet, and Security Groups as described in ./aws-vm-setup-instructions.md
2. Launch four Ubuntu 24.04 VMs and note their public IPs (for SSH) and private IPs (service endpoints)
3. Populate the public IPs / private IPs into CA0/Makefile (VM*_PUB / VM*_PRIV)
4. From your laptop, run the per-VM sequences below.

Per-VM quick commands (run from CA0/ directory on your laptop)
- VM1 (Kafka)
  - make vm1-bootstrap
  - make vm1-setup        # sets advertised listener to VM1_PRIV
  - make vm1-up
  - make vm1-logs / make -C ~/gpu-token-analytics-pipeline/CA0/vm1-kafka topics
- VM2 (MongoDB)
  - make vm2-bootstrap
  - make vm2-setup
  - make vm2-up
  - make vm2-wait
  - make vm2-stats
- VM3 (Processor)
  - make vm3-bootstrap
  - make vm3-setup
  - make vm3-up
  - make vm3-wait
  - make vm3-health / make vm3-logs
- VM4 (Producers)
  - make vm4-bootstrap
  - make vm4-setup
  - make vm4-doctor   # checks Kafka reachability using VM1 private IP
  - make vm4-run      # runs the one-shot producer (injects VM1_PRIV:9092 at runtime)

Security reminders (short)
- Use SG-to-SG rules (least-privilege): Kafka(9092) from Processor+Producers only; Mongo(27017) from Processor only; SSH from Admin IP only.
- Use private IPs for service endpoints (KAFKA_BOOTSTRAP, MONGO_URL).
- Optional: mirror SG rules with UFW on hosts for defence-in-depth.

Troubleshooting pointers
- Mongo timeouts from VM3 → check CA0/vm2-mongo logs (make vm2-logs) and Security Group inbound rules for 27017.
- Kafka client connection issues → ensure advertised.listeners is the VM1 private IP and SG allows 9092 from VM3/VM4.
- Use the Makefile doctor/doctor-like targets:
  - VM3: make vm3-doctor
  - VM4: make vm4-doctor

Deliverables & evidence
- Capture: instance list + SGs, Kafka topics list, processor /health, Mongo counts, and a short demo of producer → processor → DB.
- See ./screenshots in this folder for example captures (if present).

If you need the full, detailed walk-through (with screenshots and the exact console clicks we used), follow ./aws-vm-setup-instructions.md. For implementation and runtime details consult each VM's README listed above.
