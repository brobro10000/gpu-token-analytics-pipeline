variable "vpc_id" {
  description = "VPC ID where the k3s control-plane and worker nodes will run"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to place the control-plane and worker nodes"
  type        = string
}

variable "sg_ids" {
  description = "Map of security group IDs for the nodes (expects keys: admin, k8s_nodes)"
  type        = map(string)
}

variable "key_name" {
  description = "EC2 key pair name used for SSH access to nodes"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all cluster resources"
  type        = map(string)
  default     = {}
}

variable "name" {
  description = "Project/resource prefix used in tags and resource names"
  type        = string
}

variable "control_instance_type" {
  description = "Instance type for the k3s control-plane node"
  type        = string
  default     = "t3.small"
}

variable "worker_instance_type" {
  description = "Instance type for the k3s worker nodes"
  type        = string
  default     = "t3.small"
}

variable "worker_count" {
  description = "Number of k3s worker nodes to create"
  type        = number
  default     = 2
  validation {
    condition     = var.worker_count >= 0 && var.worker_count <= 10
    error_message = "worker_count must be between 0 and 10."
  }
}

variable "public_ip" {
  description = "Whether to associate a public IP address to each node"
  type        = bool
  default     = true
}

variable "root_volume_size_gb" {
  description = "Root disk size (GB) for all nodes"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "EBS volume type for all nodes"
  type        = string
  default     = "gp3"
  validation {
    condition     = contains(["gp3", "gp2", "io1", "io2", "standard"], var.root_volume_type)
    error_message = "root_volume_type must be one of: gp3, gp2, io1, io2, standard."
  }
}