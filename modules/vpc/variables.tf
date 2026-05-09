variable "name" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "saas-infra"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "30.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to deploy into (must match subnet CIDR list lengths)"
  type        = list(string)
  # e.g. ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["30.0.1.0/24", "30.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private app subnets (one per AZ)"
  type        = list(string)
  default     = ["30.0.11.0/24", "30.0.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private DB subnets (one per AZ)"
  type        = list(string)
  default     = ["30.0.21.0/24", "30.0.22.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateways for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cheaper, less resilient) instead of one per AZ"
  type        = bool
  default     = true
}

variable "create_db_subnet_group" {
  description = "Whether to create an RDS DB subnet group from the private DB subnets"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}

