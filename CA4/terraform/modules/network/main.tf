############################################
# Data lookups: AZs and instance offerings
############################################

# All usable AZ names/ids in the current region
data "aws_availability_zones" "available" {
  state = "available"
}

# Required instance types (unique set)
locals {
  required_types = toset(var.required_instance_types)
  available_azs  = data.aws_availability_zones.available.names
}

# For each required type, fetch AZs that offer it
data "aws_ec2_instance_type_offerings" "by_type" {
  for_each      = local.required_types
  location_type = "availability-zone"
  filter {
    name   = "instance-type"
    values = [each.key]
  }
}

# Compute the intersection of supported AZs across all required types
locals {
  # list(set(string)) of AZ sets for each type
  az_sets = [for it, ds in data.aws_ec2_instance_type_offerings.by_type : toset(ds.locations)]

  # If no required types given -> all available AZs are acceptable
  # If exactly one set -> that set
  # Else -> intersection across all sets
  common_supported_azs = (
    length(local.required_types) == 0 ? toset(local.available_azs) :
    length(local.az_sets) == 1 ? element(local.az_sets, 0) :
    toset([for az in local.available_azs : az if length([for s in local.az_sets : 1 if contains(tolist(s), az)]) == length(local.az_sets)])
  )

  # Honor preferred_az only if it's supported; otherwise pick first (sorted for determinism)
  chosen_az = (
    length(var.preferred_az) > 0 && contains(local.common_supported_azs, var.preferred_az)
    ) ? var.preferred_az : (
    length(local.common_supported_azs) > 0 ? sort(tolist(local.common_supported_azs))[0] : null
  )

  # Map AZ name -> ZoneID (ZoneIDs are stable across accounts)
  zone_id_by_name = {
    for idx, name in data.aws_availability_zones.available.names :
    name => data.aws_availability_zones.available.zone_ids[idx]
  }

  chosen_az_id = local.chosen_az != null ? lookup(local.zone_id_by_name, local.chosen_az, null) : null

  # Tag helpers
  common_tags = merge(var.tags, { Project = var.name })
}

##########################
# Network resources (VPC)
##########################

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone_id    = local.chosen_az_id
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Name = "${var.name}-public-${local.chosen_az}" })

  lifecycle {
    precondition {
      condition     = local.chosen_az != null && local.chosen_az_id != null
      error_message = "No AZ in the region supports all required instance types."
    }
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name}-rt-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
