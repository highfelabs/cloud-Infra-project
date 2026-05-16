terraform {
  backend "s3" {
    bucket         = "saas-infra-tfstate-704225640883"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "saas-infra-tf-locks"
    encrypt        = true
  }
}