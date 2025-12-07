# .tflint.hcl — compatible with TFLint v0.54+

plugin "aws" {
  enabled = true
  version = "0.43.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  # How TFLint calls modules:
  # - "all"         : lint root + all child modules
  # - "local_only"  : lint root + only local child modules
  # - "none"        : lint only the current dir (legacy behavior)
  call_module_type = "all"

  # Fail on rule errors (default behavior). Set true to force exit on warnings-as-errors in some setups.
  force = false
}

# (Optional) enable or tune specific rules later, e.g.:
# rule "terraform_unused_declarations" { enabled = true }
# rule "aws_instance_invalid_type"     { enabled = true }
# rule "aws_security_group_ingress_open_to_world" { enabled = true }
