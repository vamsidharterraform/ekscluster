GitHub Actions Terraform Pipelines
Repository structure
.
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── ...
│   └── test/
│       ├── main.tf
│       ├── variables.tf
│       └── ...
└── .github/
    └── workflows/
        ├── cluster_from_github_dev.yml
        └── cluster_from_github_test.yml
DEV pipeline
cluster_from_github_dev runs Terraform from:
environments/dev
Commands:
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
TEST pipeline
cluster_from_github_test runs Terraform from:
environments/test
Commands:
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
Both workflows use the EC2 GitHub self-hosted runner:
runs-on: [self-hosted, linux, x64]
In GitHub:
Actions
  -> cluster_from_github_dev
  -> Run workflow
or:
Actions
  -> cluster_from_github_test
  -> Run workflow
The runner EC2 needs AWS permissions. Prefer an IAM role attached to the EC2 rather than long-lived AWS access keys.