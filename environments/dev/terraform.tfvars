# project     = "myapp"
# environment = "prod"
# aws_region  = "us-east-1"

# # Networking
# vpc_cidr           = "10.0.0.0/16"
# availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
# private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
# private_db_subnet_cidrs  = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

# # ALB
# certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id"
# app_port          = 80
# health_check_path = "/health"

# # EC2 / ASG
# instance_type        = "t3.medium"
# root_volume_size     = 20
# asg_min_size         = 2
# asg_max_size         = 6
# asg_desired_capacity = 2

# db_server_instance_type = "t3.small"

# # RDS
# db_engine                 = "mysql"
# db_engine_version         = "8.0"
# db_parameter_group_family = "mysql8.0"
# db_instance_class         = "db.t3.medium"
# db_name                   = "myappdb"
# db_username               = "admin"
# db_port                   = 3306
# db_allocated_storage      = 20
# db_max_allocated_storage  = 100