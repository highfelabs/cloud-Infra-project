# ─────────────────────────────────────────────
#  RDS Parameter Group
#  Lets you tune DB engine settings per env
# ─────────────────────────────────────────────
resource "aws_db_parameter_group" "this" {
  name        = "${var.name}-pg"
  family      = var.parameter_group_family
  description = "Parameter group for ${var.name}"

  tags = merge(var.tags, { Name = "${var.name}-pg" })
}

# ─────────────────────────────────────────────
#  RDS Subnet Group
#  Uses private DB subnets from VPC module
# ─────────────────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-subnet-group" })
}

# ─────────────────────────────────────────────
#  Random password for RDS master user
#  Stored in Secrets Manager automatically
# ─────────────────────────────────────────────
resource "random_password" "master" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|;:,.<>?"
}

# ─────────────────────────────────────────────
#  Secrets Manager — RDS credentials
#  App servers read from here instead of
#  hardcoded env vars
# ─────────────────────────────────────────────
resource "aws_secretsmanager_secret" "rds" {
  name                    = "${var.name}/rds/credentials"
  description             = "RDS master credentials for ${var.name}"
  recovery_window_in_days = var.secret_recovery_window

  tags = merge(var.tags, { Name = "${var.name}-rds-secret" })
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.master.result
    host     = aws_db_instance.this.address
    port     = var.db_port
    dbname   = var.db_name
    engine   = var.engine
  })
}

# ─────────────────────────────────────────────
#  RDS Instance
#  Multi-AZ for prod, single AZ for staging
# ─────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier = "${var.name}-rds"

  # Engine
  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  parameter_group_name = aws_db_parameter_group.this.name

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  # Credentials
  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result

  # Network
  db_subnet_group_name   = aws_db_subnet_group.this.name
  #vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = var.db_port

  # Availability
  multi_az = var.multi_az

  # Backups
  backup_retention_period   = var.backup_retention_days
  backup_window             = "03:00-04:00"
  maintenance_window        = "mon:04:00-mon:05:00"
  delete_automated_backups  = false
  copy_tags_to_snapshot     = true
  final_snapshot_identifier = "${var.name}-rds-final-snapshot"
  skip_final_snapshot       = var.skip_final_snapshot

  # Monitoring
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn
  enabled_cloudwatch_logs_exports = var.cloudwatch_logs_exports
  performance_insights_enabled    = false

  # Protection
  deletion_protection = var.deletion_protection

  # Apply changes immediately in non-prod, during window in prod
  apply_immediately = var.apply_immediately

  tags = merge(var.tags, { Name = "${var.name}-rds" })
}

# ─────────────────────────────────────────────
#  IAM Role for RDS Enhanced Monitoring
# ─────────────────────────────────────────────
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ─────────────────────────────────────────────
#  CloudWatch Alarms for RDS
# ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.name}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU above 80%"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.name}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 5368709120 # 5 GB in bytes
  alarm_description   = "RDS free storage below 5GB"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.name}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.max_connections_alarm_threshold
  alarm_description   = "RDS connection count is high"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }

  tags = var.tags
}