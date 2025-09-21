variable "name" {
  description = "Project name for tags"
  type        = string
}

variable "subnet_id" {
  description = "Subnet to place instances in"
  type        = string
}

variable "sg_ids" {
  description = "Security groups map: admin, kafka, mongo, processor, producers"
  type        = map(string)
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "public_ip" {
  description = "Associate public IP addresses to instances"
  type        = bool
  default     = true
}

# Per-VM instance types (x86 only)
variable "vm1_instance_type" {
  description = "Instance type for Kafka VM"
  type        = string
  default     = "t3.small"
}

variable "vm2_instance_type" {
  description = "Instance type for MongoDB VM"
  type        = string
  default     = "t3.small"
}

variable "vm3_instance_type" {
  description = "Instance type for Processor VM"
  type        = string
  default     = "t3.micro"
}

variable "vm4_instance_type" {
  description = "Instance type for Producers VM"
  type        = string
  default     = "t3.micro"
}

# App/env (only the price is provided as input; endpoints are resolved from other instances)
variable "price_per_hour_usd" {
  description = "Float value used by processor"
  type        = number
  default     = 0.85
}
