output "alb_sg_id" {
  description = "Security group ID of the ALB. Pass to the ALB module."
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "Security group ID of the app servers. Pass to the launch template module."
  value       = aws_security_group.app.id
}

output "rds_sg_id" {
  description = "Security group ID of the DB subnet server. Pass to the db-server module."
  value       = aws_security_group.rds.id
}

# output "bastion_sg_id" {
#   description = "Security group ID of the bastion server. Pass to the db-server module."
#   value = aws_security_group.bastion.id
# }
