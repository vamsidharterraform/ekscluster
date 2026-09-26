environment     = "test"
cluster_name    = "test-app-cluster"
cluster_version = "1.33"

vpc_cidr = "10.20.0.0/16"

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
      desired_size = 3
      min_size     = 2
      max_size     = 5
    }
  }
}