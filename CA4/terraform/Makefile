# Makefile for Terraform in CA3 (run from ca3/terraform)

# -------- Config (override via env if you like) --------
AWS_PROFILE ?= terraform
AWS_REGION  ?= us-east-1

# Auto-detect caller IP each run unless you set MY_IP_CIDR yourself
MY_IP_CIDR  ?= $(shell curl -s ifconfig.me)/32
# Optional: only needed if you don't keep ssh_key_name in terraform.tfvars
SSH_KEY_NAME ?=

# Compose optional -var flags dynamically
TFVARS_SSH := $(if $(SSH_KEY_NAME),-var="ssh_key_name=$(SSH_KEY_NAME)",)
TFVARS_IP  := -var="my_ip_cidr=$(MY_IP_CIDR)"

# Internal: plan filename
PLAN_FILE := tfplan

# -------- Targets --------
.PHONY: help init init-upgrade validate fmt lint-init lint plan apply deploy outputs \
        destroy down clean nuke ip show state

help:
	@echo "CA4 Terraform helpers:"
	@echo "  make deploy        -> init + plan (with auto IP) + apply"
	@echo "  make plan          -> create $(PLAN_FILE) (auto IP, optional SSH key)"
	@echo "  make apply         -> apply saved plan"
	@echo "  make down          -> terraform destroy (auto IP, optional SSH key)"
	@echo "  make outputs       -> show terraform outputs"
	@echo "  make validate      -> terraform validate"
	@echo "  make fmt           -> terraform fmt -recursive"
	@echo "  make lint-init     -> tflint --init"
	@echo "  make lint          -> tflint (AWS_PROFILE/REGION respected)"
	@echo "  make clean         -> remove .terraform/ and $(PLAN_FILE) (keep state)"
	@echo "  make nuke          -> REMOVE LOCAL STATE (danger)"
	@echo "  make ip            -> echo detected MY_IP_CIDR"
	@echo "  make show          -> terraform show"
	@echo "  make state         -> terraform state list"

# Initialize providers/modules (safe to rerun)
init:
	AWS_PROFILE=$(AWS_PROFILE) terraform init

# Upgrade provider/plugins if versions changed
init-upgrade:
	AWS_PROFILE=$(AWS_PROFILE) terraform init -upgrade

validate:
	AWS_PROFILE=$(AWS_PROFILE) terraform validate

fmt:
	terraform fmt -recursive

lint-init:
	tflint --init

lint:
	AWS_PROFILE=$(AWS_PROFILE) AWS_REGION=$(AWS_REGION) tflint -f compact

# Create a plan file (validates + shows actions)
plan:
	AWS_PROFILE=$(AWS_PROFILE) terraform plan -out=$(PLAN_FILE) $(TFVARS_SSH) $(TFVARS_IP)

# Apply the saved plan
apply:
	AWS_PROFILE=$(AWS_PROFILE) terraform apply $(PLAN_FILE)

# One-shot: init + plan + apply
deploy: init plan apply

# Show outputs
outputs:
	AWS_PROFILE=$(AWS_PROFILE) terraform output

# Destroy everything managed by this config
down:
	AWS_PROFILE=$(AWS_PROFILE) terraform destroy $(TFVARS_SSH) $(TFVARS_IP)

# Utilities
ip:
	@echo $(MY_IP_CIDR)

show:
	AWS_PROFILE=$(AWS_PROFILE) terraform show

state:
	AWS_PROFILE=$(AWS_PROFILE) terraform state list

# Safe clean: removes cache & plan, keeps state
clean:
	rm -rf .terraform $(PLAN_FILE) .terraform.lock.hcl

# Nuclear option: removes everything including local state (DANGEROUS)
nuke:
	rm -rf .terraform $(PLAN_FILE) terraform.tfstate* .terraform.lock.hcl
