# Network module (single-AZ, auto-selects a supported AZ)

This module creates:
- A VPC
- An Internet Gateway
- One public subnet **in an AZ that supports all requested instance types**
- Route table + association

It prevents the classic error:
> Unsupported: Your requested instance type is not supported in your requested Availability Zone

by **intersecting** the AZ offerings for each instance type you plan to launch and picking a valid AZ
(or honoring `preferred_az` only if supported).

## Inputs

- `name` (string): Project/name prefix used in tags.
- `cidr_block` (string): VPC CIDR. Default `10.0.0.0/16`.
- `public_subnet_cidr` (string): Public subnet CIDR. Default `10.0.1.0/24`.
- `preferred_az` (string): Optional AZ name. Used **only if** it supports all instance types.
- `required_instance_types` (list(string)): Instance types you intend to run (e.g., `["t3.small","t3.micro"]`).

> If `required_instance_types` is empty, we pick the first available AZ in the region.

## Outputs

- `vpc_id`
- `subnet_id`
- `chosen_az`   (e.g., `us-east-1a`)
- `chosen_az_id` (stable ZoneID, e.g., `use1-az1`)

## Usage (root module)

```hcl
module "network" {
  source = "./modules/network"

  name                   = var.name
  cidr_block             = "10.0.0.0/16"
  public_subnet_cidr     = "10.0.1.0/24"
  preferred_az           = var.preferred_az           # optional
  required_instance_types = [
    var.vm1_instance_type,  # Kafka
    var.vm2_instance_type,  # Mongo
    var.vm3_instance_type,  # Processor
    var.vm4_instance_type,  # Producers
  ]
}

# Then point your instances at this subnet:
# subnet_id = module.network.subnet_id
# (No need to set availability_zone on aws_instance; the subnet dictates the AZ.)
