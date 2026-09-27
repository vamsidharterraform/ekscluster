terraform {
  backend "s3" {
    bucket         = "vamsi-terraform-state-dev-usw2"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-eks-state-locks"
    encrypt        = true
  }
}