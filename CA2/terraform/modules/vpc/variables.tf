variable "name" {
  description = "Project/name prefix used in VPC and subnet names/tags"
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the VPC (e.g., 10.0.0.0/16)"
  type        = string
}

variable "subnet_cidr" {
  description = "IPv4 CIDR for the public subnet (e.g., 10.0.1.0/24)"
  type        = string
}

variable "public_subnet" {
  description = "Whether the subnet should auto-assign public IPs and route to an Internet Gateway"
  type        = bool
}
