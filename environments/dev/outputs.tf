output "rds_endpoint" {
  description = "RDS connection endpoint"
  value       = module.rds.rds_endpoint
}

output "rds_address" {
  description = "RDS hostname only"
  value       = module.rds.rds_address
}

output "alb_dns_name" {
  description = "Open this in your browser"
  value       = module.alb.alb_dns_name
}

output "app_bucket_name" {
  value = module.s3.app_bucket_name
}
output "rds_password" {
  description = "RDS master password"
  value       = module.rds.rds_password
  sensitive   = true
}

output "rds_secret_name" {
  description = "Secrets Manager secret name"
  value       = module.rds.rds_secret_name
}
