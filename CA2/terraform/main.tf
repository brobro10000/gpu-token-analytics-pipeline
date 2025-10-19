#######################################
# Network (VPC + Subnet in supported AZ)
#######################################
module "network" {
  source = "./modules/network"

  name               = var.project_name
  cidr_block         = var.vpc_cidr     # e.g., "10.0.0.0/16"
  public_subnet_cidr = var.subnet_cidr  # e.g., "10.0.1.0/24"
  preferred_az       = var.preferred_az # "" to auto-pick a supported AZ

  # Ensure the AZ we choose supports all types we plan to launch
  required_instance_types = [
    var.vm1_instance_type, # Kafka
    var.vm2_instance_type, # Mongo
    var.vm3_instance_type, # Processor
    var.vm4_instance_type, # Producers
    var.control_instance_type,
    var.worker_instance_type
  ]

  tags = var.tags
}

#######################################
# Security Groups (wired to the VPC above)
#######################################
module "security_groups" {
  source         = "./modules/security_groups"
  name           = var.project_name
  vpc_id         = module.network.vpc_id
  my_ip_cidr     = var.my_ip_cidr
  vpc_cidr_block = module.network.vpc_cidr_block
}

#######################################
# Instances (wired to subnet + SGs above)
#######################################
module "instances" {
  count  = var.enable_ca1_instances ? 1 : 0
  source = "./modules/instances"
  name   = var.project_name

  subnet_id = module.network.subnet_id
  sg_ids    = module.security_groups.sg_ids

  key_name  = var.ssh_key_name
  public_ip = var.public_subnet # bool: associate_public_ip_address

  vm1_instance_type = var.vm1_instance_type # "t3.small"
  vm2_instance_type = var.vm2_instance_type # "t3.small"
  vm3_instance_type = var.vm3_instance_type # "t3.micro"
  vm4_instance_type = var.vm4_instance_type # "t3.micro"

  price_per_hour_usd = var.price_per_hour_usd
}

#######################################
# Cluster
#######################################
module "cluster" {
  source    = "./modules/cluster"
  name      = var.project_name
  vpc_id    = module.network.vpc_id
  subnet_id = module.network.subnet_id
  sg_ids    = module.security_groups.sg_ids
  key_name  = var.ssh_key_name
  public_ip = true
  tags      = var.tags
}


