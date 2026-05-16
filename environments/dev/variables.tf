variable "aws_region" {
  description = "AWS region to deploy all resources into"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "saas-infra"
}

variable "db_name" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "db_infra"
}

variable "environment" {
  description = "Environment name — dev, staging, prod"
  type        = string
  default     = "dev"
}