variable "name" {
  description = "Name prefix for all security groups"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to create security groups in"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC. Used to scope ICMP and DB egress rules to intra-VPC traffic only."
  type        = string
}

variable "app_sg_id" {
  description = "Security group ID of the app servers. Only this SG is granted DB access."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all security groups"
  type        = map(string)
  default     = {}
}

variable "db_port" {
  description = "Port the database listens on (3306 for MySQL, 5432 for Postgres)"
  type        = number
  default     = 3306
}