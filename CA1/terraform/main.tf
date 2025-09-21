module "vpc" {
  source        = "./modules/vpc"
  name          = var.project_name
  vpc_cidr      = var.vpc_cidr
  subnet_cidr   = var.subnet_cidr
  public_subnet = var.public_subnet
}

module "security_groups" {
  source     = "./modules/security_groups"
  name       = var.project_name
  vpc_id     = module.vpc.vpc_id # ← from VPC module output
  my_ip_cidr = var.my_ip_cidr
}

module "instances" {
  source    = "./modules/instances"
  name      = var.project_name
  subnet_id = module.vpc.subnet_id          # ← from VPC module output
  sg_ids    = module.security_groups.sg_ids # ← from SG module output
  key_name  = var.ssh_key_name
  public_ip = var.public_subnet

  vm1_instance_type = "t3.small"
  vm2_instance_type = "t3.small"
  vm3_instance_type = "t3.micro"
  vm4_instance_type = "t3.micro"

  price_per_hour_usd = 0.85
}
