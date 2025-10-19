output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.this.id
}

output "subnet_id" {
  description = "ID of the public subnet in a supported AZ."
  value       = aws_subnet.public.id
}

output "chosen_az" {
  description = "Name of the Availability Zone selected (e.g., us-east-1a)."
  value       = local.chosen_az
}

output "chosen_az_id" {
  description = "Stable Zone ID of the selected AZ (e.g., use1-az1)."
  value       = local.chosen_az_id
}

output "vpc_cidr_block" {
  description = ""
  value       = aws_vpc.this.cidr_block
}
