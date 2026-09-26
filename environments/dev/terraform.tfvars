environment     = "dev"
cluster_name    = "dev-app-cluster"
cluster_version = "1.33"

vpc_cidr = "10.10.0.0/16"

public_subnet_cidrs = [
  "10.10.1.0/24",
  "10.10.2.0/24",
  "10.10.3.0/24"
]

private_subnet_cidrs = [
  "10.10.11.0/24",
  "10.10.12.0/24",
  "10.10.13.0/24"
]

availability_zones = [
  "us-west-2a",
  "us-west-2b",
  "us-west-2c"
]


node_groups = {
  system = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"

    scaling_config = {
      desired_size = 2
      min_size     = 2
      max_size     = 3
    }
  }

  application = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"

    scaling_config = {
      desired_size = 1
      min_size     = 2
      max_size     = 3
    }
  }
}