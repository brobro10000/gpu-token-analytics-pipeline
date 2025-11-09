variable "project_name" {
  description = "Project/name prefix used across modules and in tags"
  type        = string
  default     = "ca3"
}

variable "aws_region" {
  description = "Deprecated: prefer 'region' variable; kept for back-compat (not used by provider)"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS shared credentials profile name used by the AWS provider"
  type        = string
  default     = "terraform"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC (e.g., 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "IPv4 CIDR block for the public subnet (e.g., 10.0.1.0/24)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet" {
  description = "If true, create a public subnet with Internet routing and auto-assigned public IPs"
  type        = bool
  default     = true
}

variable "ssh_key_name" {
  description = "EC2 key pair name to associate with instances and cluster nodes for SSH access"
  type        = string
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR notation (e.g., 203.0.113.25/32) to allow SSH/kubectl access"
  type        = string
}

variable "region" {
  description = "AWS region for all resources (used by the AWS provider)"
  type        = string
  default = "us-east-1"
}

variable "preferred_az" {
  description = "Optional Availability Zone to prefer; falls back to an auto-selected supported AZ when empty"
  type        = string
  default     = ""
}

variable "name" {
  description = "Deprecated: use project_name instead (kept for back-compat)"
  type        = string
  default     = "ca3"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "key_name" {
  description = "Deprecated: use ssh_key_name instead (kept for back-compat)"
  type        = string
  default     = "ca0"
}

variable "public_ip" {
  description = "Deprecated at root: module-specific flags are used instead"
  type        = bool
  default     = true
}

variable "vm1_instance_type" {
  description = "Instance type for Kafka VM (legacy CA1)"
  type        = string
  default     = "t3.small"
}

variable "vm2_instance_type" {
  description = "Instance type for MongoDB VM (legacy CA1)"
  type        = string
  default     = "t3.small"
}

variable "vm3_instance_type" {
  description = "Instance type for Processor VM (legacy CA1)"
  type        = string
  default     = "t3.micro"
}

variable "vm4_instance_type" {
  description = "Instance type for Producers VM (legacy CA1)"
  type        = string
  default     = "t3.micro"
}

variable "control_instance_type" {
  description = "Instance type for the k3s control-plane node"
  type        = string
  default     = "c7i-flex.large"
}

variable "worker_instance_type" {
  description = "Instance type for the k3s worker nodes"
  type        = string
  default     = "t3.small"
}


variable "price_per_hour_usd" {
  description = "Float value used by the processor app (pricing input)"
  type        = number
  default     = 0.85
}

variable "enable_ca1_instances" {
  description = "Whether to provision the legacy CA1 instances module"
  type        = bool
  default     = false
}

