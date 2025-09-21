locals { tags = { Project = var.name } }

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.name}-vpc" })
}

resource "aws_subnet" "this" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = var.public_subnet
  tags                    = merge(local.tags, { Name = "${var.name}-subnet" })
}

# (IGW/route table here if public_subnet=true)

output "vpc_id" { value = aws_vpc.this.id }
output "subnet_id" { value = aws_subnet.this.id }
