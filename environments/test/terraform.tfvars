environment     = "test"
cluster_name    = "test-app-cluster"
cluster_version = "1.33"

vpc_cidr = "10.20.0.0/16"

aws_region = "us-west-2"

public_subnet_cidrs = [
  "10.20.1.0/24",
  "10.20.2.0/24",
  "10.20.3.0/24"
]

private_subnet_cidrs = [
  "10.20.11.0/24",
  "10.20.12.0/24",
  "10.20.13.0/24"
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
    instance_types = ["t3.large"]
    capacity_type  = "ON_DEMAND"

    scaling_config = {
      desired_size = 1
      min_size     = 1
      max_size     = 2
    }
  }
}