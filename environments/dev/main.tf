module "vpc" {
  source = "git::https://github.com/vamsidharterraform/vpcmodule.git?ref=main"

  Environment = var.environment
  vpc_cidr    = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnet = var.public_subnet_cidrs
  private_subnet = var.private_subnet_cidrs
}

module "eks" {
  source = "git::https://github.com/vamsidharterraform/eksmodule.git//eks?ref=main"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  Environment     = var.environment
  vpc_id          = module.vpcmodule.aws_vpc.id

  subnet_ids = module.vpc.private_subnet_ids

  node_groups = var.node_groups
}