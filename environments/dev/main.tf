module "vpc" {
  source = "git::https://github.com/vamsidharterraform/vpcmodule.git?ref=main"

  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = var.cluster_name
}

module "eks" {
  source = "git::https://github.com/vamsidharterraform/eksmodule.git//eks?ref=main"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id

  subnet_ids = module.vpc.private_subnet_ids

  node_groups = var.node_groups
}