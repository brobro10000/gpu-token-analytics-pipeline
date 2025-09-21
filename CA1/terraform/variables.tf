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
