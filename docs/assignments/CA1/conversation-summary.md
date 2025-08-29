# Conversation Summary — CA1

Context
- Add IaC architecture and README as part of the consolidated PR.

Decisions & Tradeoffs
- Split infra (Terraform) from config (Ansible) for clarity.
- Secrets via cloud Secret Manager or HashiCorp Vault (no-cost OSS).
- Keep VM sizing flexible via variables.

AI Assistance
- Copilot drafted structure, diagrams, and steps; aligned to CS5287 roadmap.

Next
- Provide starter IaC skeleton in a later PR or separate branch.