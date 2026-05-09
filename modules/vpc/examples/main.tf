provider "aws" {
  region = "us-east-1"
}

# ── Production (multi-AZ NAT, fully resilient) ──────────────────────────────
module "vpc_prod" {
  source = "./vpc-module"

  name               = "myapp-prod"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  private_db_subnet_cidrs  = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = false   # one NAT per AZ for HA
  create_db_subnet_group = true

  tags = {
    Environment = "production"
    Project     = "myapp"
    ManagedBy   = "terraform"
  }
}

# ── Staging (single NAT to save cost) ──────────────────────────────────────
module "vpc_staging" {
  source = "./vpc-module"

  name               = "myapp-staging"
  vpc_cidr           = "10.1.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs      = ["10.1.1.0/24", "10.1.2.0/24"]
  private_app_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]
  private_db_subnet_cidrs  = ["10.1.21.0/24", "10.1.22.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true   # cheaper for non-prod
  create_db_subnet_group = true

  tags = {
    Environment = "staging"
    Project     = "myapp"
    ManagedBy   = "terraform"
  }
}

# ── Referencing outputs in other resources ──────────────────────────────────
# Pass VPC outputs directly to your ALB, ASG, RDS modules:

# resource "aws_lb" "app" {
#   subnets = module.vpc_prod.public_subnet_ids
#   ...
# }

# resource "aws_autoscaling_group" "app" {
#   vpc_zone_identifier = module.vpc_prod.private_app_subnet_ids
#   ...
# }

# resource "aws_db_instance" "main" {
#   db_subnet_group_name = module.vpc_prod.db_subnet_group_name
#   ...
# }
