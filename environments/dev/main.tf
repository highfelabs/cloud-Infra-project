locals {
  tags = {
    Environment = var.environment
    Project     = var.name
    ManagedBy   = "terraform"
  }
}


# ─────────────────────────────────────────────
#  Data Sources
#  Latest Amazon Linux 2023 AMI - SSM Parameter Store
# ─────────────────────────────────────────────

data "aws_ssm_parameter" "amazon_linux" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────
#  IAM Role + Instance Profile (SSM-enabled)
# ─────────────────────────────────────────────
resource "aws_iam_role" "app" {
  name = "${var.name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.app.name
  policy_arn = module.s3.app_s3_policy_arn
}

# Allow app servers to read RDS credentials from Secrets Manager
resource "aws_iam_role_policy" "secrets" {
  name = "${var.name}-secrets-policy"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [module.rds.rds_secret_arn]
    }]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.app.name
}



# ─────────────────────────────────────────────
#  MODULE: VPC
# ─────────────────────────────────────────────
module "vpc" {
  source             = "../../modules/vpc"
  name               = var.name
  availability_zones = ["us-east-1a", "us-east-1b"]

  tags = local.tags
}

# ─────────────────────────────────────────────
#  MODULE: Security Groups
#  Depends on: vpc
# ─────────────────────────────────────────────
module "sg" {
  source   = "../../modules/sg"
  name     = var.name
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = module.vpc.vpc_cidr
  #app_sg_id           = module.sg.app_sg_id
  tags = local.tags
}

# ─────────────────────────────────────────────
#  MODULE: S3
#  Created before launch template — bucket name
#  is injected into user data via templatefile()
# ─────────────────────────────────────────────
module "s3" {
  source = "../../modules/s3"

  name                    = var.name
  bucket_suffix           = data.aws_caller_identity.current.account_id
  enable_versioning       = true
  create_alb_logs_bucket  = true
  alb_logs_retention_days = 30

  tags = local.tags
}

# ─────────────────────────────────────────────
#  MODULE: RDS
#  Created before launch template — secret name
#  is injected into user data via templatefile()
# ─────────────────────────────────────────────
module "rds" {
  source        = "../../modules/rds"
  name          = var.name
  db_name       = var.db_name
  aws_region    = var.aws_region
  vpc_id        = module.vpc.vpc_id
  db_subnet_ids = module.vpc.private_db_subnet_ids
  app_sg_id     = module.sg.app_sg_id
  rds_sg_id     = module.sg.rds_sg_id
  tags          = local.tags
}

# ─────────────────────────────────────────────
#  MODULE: Launch Template
#  Depends on: sg
# ─────────────────────────────────────────────
module "launch-template" {
  source               = "../../modules/launch-template"
  name                 = var.name
  app_sg_id            = module.sg.app_sg_id
  ami_id               = data.aws_ssm_parameter.amazon_linux.value
  iam_instance_profile = aws_iam_instance_profile.app.name
  user_data = templatefile("${path.module}/user_data.sh", {
    environment    = var.environment
    db_secret_name = module.rds.rds_secret_name
    s3_bucket      = module.s3.app_bucket_name
    aws_region     = var.aws_region
  })

  tags = local.tags

}

# ─────────────────────────────────────────────
#  MODULE: ALB + Target Group + Listeners
#  Depends on: vpc, sg
# ─────────────────────────────────────────────
module "alb" {
  source                     = "../../modules/alb"
  name                       = var.name
  vpc_id                     = module.vpc.vpc_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  alb_sg_id                  = module.sg.alb_sg_id
  enable_deletion_protection = false
  tags                       = local.tags
}

# ─────────────────────────────────────────────
#  MODULE: Auto Scaling Group
#  Depends on: vpc, launch_template, alb
# ─────────────────────────────────────────────
module "asg" {
  source             = "../../modules/asg"
  name               = var.name
  launch_template_id = module.launch-template.id
  target_group_arn   = module.alb.target_group_arn
  private_subnet_ids = module.vpc.private_app_subnet_ids
  tags = merge(local.tags, {
    SecretVersion = module.rds.secret_version_id
  })
}