output "rds_password" {
  description = "RDS master password"
  value       = random_password.master.result
  sensitive   = true
}

output "rds_endpoint" {
  description = "RDS instance connection endpoint (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "rds_address" {
  description = "RDS instance hostname — use this in your app config"
  value       = aws_db_instance.this.address
}

output "rds_port" {
  description = "Port the RDS instance listens on"
  value       = aws_db_instance.this.port
}

output "rds_db_name" {
  description = "Name of the initial database created"
  value       = aws_db_instance.this.db_name
}

output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.this.identifier
}

output "secret_version_id" {
  description = "Secret version ID — changes every time secret is updated"
  value       = aws_secretsmanager_secret_version.rds.version_id
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret holding RDS credentials. Reference this in your app IAM policy."
  value       = aws_secretsmanager_secret.rds.arn
}

output "rds_secret_name" {
  description = "Name of the Secrets Manager secret — use to fetch credentials in user data or app config"
  value       = aws_secretsmanager_secret.rds.name
}
