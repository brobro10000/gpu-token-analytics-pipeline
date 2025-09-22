locals {
  tags = { Project = var.name }
}

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

# Create IGW + public route only when public_subnet=true
resource "aws_internet_gateway" "this" {
  count  = var.public_subnet ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-igw" })
}

resource "aws_route_table" "public" {
  count  = var.public_subnet ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route" "public_internet_access" {
  count                  = var.public_subnet ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public_assoc" {
  count          = var.public_subnet ? 1 : 0
  subnet_id      = aws_subnet.this.id
  route_table_id = aws_route_table.public[0].id
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_id" {
  value = aws_subnet.this.id
}
