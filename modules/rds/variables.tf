variable "name" {
  description = "Name prefix for all RDS resources"
  type        = string
  default     = "saas-infra"

}

variable "aws_region" {
  description = "AWS region — used by the RDS waiter"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID to create the RDS security group in"
  type        = string
}

variable "db_subnet_ids" {
  description = "List of private DB subnet IDs for the RDS subnet group. Output from the VPC module."
  type        = list(string)
}

variable "app_sg_id" {
  description = "Security group ID of the app servers. Only this SG is granted DB access."
  type        = string
}

variable "rds_sg_id" {
  description = "Security group ID to attach to the RDS instance"
  type        = string
}

# ── Engine ───────────────────────────────────────────────────────────────────
variable "engine" {
  description = "Database engine (mysql, postgres, mariadb)"
  type        = string
  default     = "mysql"
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "8.0"
}

variable "parameter_group_family" {
  description = "DB parameter group family (e.g. mysql8.0, postgres15)"
  type        = string
  default     = "mysql8.0"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

# ── Database ─────────────────────────────────────────────────────────────────
variable "db_name" {
  description = "Name of the initial database to create"
  type        = string
  
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "admin"
}

variable "db_port" {
  description = "Port the database listens on (3306 for MySQL, 5432 for Postgres)"
  type        = number
  default     = 3306
}

# ── Storage ──────────────────────────────────────────────────────────────────
variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage in GB for autoscaling. Set equal to allocated_storage to disable."
  type        = number
  default     = 20
}

variable "kms_key_arn" {
  description = "KMS key ARN for storage encryption. Leave empty to use the default AWS-managed key."
  type        = string
  default     = null
}

# ── Availability ─────────────────────────────────────────────────────────────
variable "multi_az" {
  description = "Enable Multi-AZ deployment. Set true for production, false for staging to save cost."
  type        = bool
  default     = false
}

# ── Backups ───────────────────────────────────────────────────────────────────
variable "backup_retention_days" {
  description = "Number of days to retain automated backups. 0 disables backups."
  type        = number
  default     = 0
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy. Set true for staging, false for production."
  type        = bool
  default     = true
}

# ── Protection ────────────────────────────────────────────────────────────────
variable "deletion_protection" {
  description = "Prevent the database from being deleted. Set true for production."
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Apply changes immediately instead of during the maintenance window. Use true for staging only."
  type        = bool
  default     = true
}

# ── Monitoring ────────────────────────────────────────────────────────────────
variable "cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch (e.g. [audit, error, general, slowquery] for MySQL)"
  type        = list(string)
  default     = ["error", "slowquery"]
}

variable "max_connections_alarm_threshold" {
  description = "Number of connections that triggers the high-connections CloudWatch alarm"
  type        = number
  default     = 100
}

# ── Secrets Manager ───────────────────────────────────────────────────────────
variable "secret_recovery_window" {
  description = "Days before a deleted secret is permanently removed. Set 0 for immediate deletion in staging."
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags to apply to all RDS resources"
  type        = map(string)
  default     = {}
}
