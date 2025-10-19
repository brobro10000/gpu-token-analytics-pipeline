variable "name" {
  description = "Project/name prefix used in tags and resource names."
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block."
  type        = string
  default     = "10.0.1.0/24"
}

variable "preferred_az" {
  description = "Optional AZ name (e.g., us-east-1a). Honored only if it supports all required instance types; otherwise a supported AZ is auto-selected."
  type        = string
  default     = ""
}

variable "required_instance_types" {
  description = "Instance types you plan to launch (e.g., [\"t3.small\", \"t3.micro\"]). Used to compute the intersection of supported AZs."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all network resources."
  type        = map(string)
  default     = {}
}
