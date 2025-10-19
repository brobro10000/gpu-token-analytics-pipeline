variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "security_group_ids" { type = list(string) }
variable "key_name" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

variable "control_instance_type" {
  type    = string
  default = "t3.small"
}
variable "worker_instance_type" {
  type    = string
  default = "t3.small"
}
variable "worker_count" {
  type    = number
  default = 2
}