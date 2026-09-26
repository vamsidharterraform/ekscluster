terraform {
  backend "s3" {
    bucket         = "vamsi-eks-terraform-state-usw2"
    key            = "test/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-eks-state-locks"
    encrypt        = true
  }
}