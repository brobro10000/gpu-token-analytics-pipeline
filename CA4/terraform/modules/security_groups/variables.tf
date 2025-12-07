variable "name" {
  description = "Project/name prefix used in SG names and tags"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security groups will be created"
  type        = string
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR notation (e.g., 203.0.113.25/32) for admin/kubectl access"
  type        = string
}

variable "vpc_cidr_block" {
  description = "The VPC IPv4 CIDR. Used for cluster-internal rules (kubelet, NodePorts)."
  type        = string
}

variable "enable_nodeports" {
  description = "Whether to open NodePort range (30000-32767) within the VPC CIDR on k8s nodes"
  type        = bool
  default     = true
}

variable "enable_ca1_sgs" {
  description = "Whether to also create legacy CA1 app SGs (Kafka/Mongo/Processor/Producers). Safe to keep false for CA4."
  type        = bool
  default     = false
}
