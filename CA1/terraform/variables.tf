variable "project_name" {
  type    = string
  default = "ca1"
}
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "aws_profile" {
  type    = string
  default = "terraform"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}
variable "public_subnet" {
  type    = bool
  default = true
}
variable "ssh_key_name" { type = string }
variable "my_ip_cidr" { type = string } # e.g., "203.0.113.25/32"

variable "region" {
  type = string
}

variable "preferred_az" {
  type    = string
  default = ""
}

variable "name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "key_name" {
  type = string
}

variable "public_ip" {
  type    = bool
  default = true
}

variable "vm1_instance_type" {
  type    = string
  default = "t3.small"
}
variable "vm2_instance_type" {
  type    = string
  default = "t3.small"
}
variable "vm3_instance_type" {
  type    = string
  default = "t3.micro"
}
variable "vm4_instance_type" {
  type    = string
  default = "t3.micro"
}
variable "price_per_hour_usd" {
  description = "Float value used by processor"
  type        = number
  default     = 0.85
}

