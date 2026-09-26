module "vpc" {
  source = "git::https://github.com/vamsidharterraform/vpcmodule.git?ref=main"

  environment = var.environment
  vpc_cidr    = var.vpc_cidr
}

module "eks" {
  source = "git::https://github.com/vamsidharterraform/eksmodule.git//eks?ref=main"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  environment     = var.environment

  subnet_ids = module.vpc.private_subnet_ids

  node_groups = var.node_groups
}