module "vpc" {
  source = "../../modules/vpc"
  name = "saas-infra"
  availability_zones = ["us-east-1a"]
  tags = {Environment = "dev"}
}
