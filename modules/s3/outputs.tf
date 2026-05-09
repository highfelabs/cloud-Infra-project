output "app_bucket_name" {
  description = "Name of the app S3 bucket"
  value       = aws_s3_bucket.app.bucket
}

output "app_bucket_arn" {
  description = "ARN of the app S3 bucket"
  value       = aws_s3_bucket.app.arn
}

output "app_bucket_id" {
  description = "ID of the app S3 bucket"
  value       = aws_s3_bucket.app.id
}

output "alb_logs_bucket_name" {
  description = "Name of the ALB logs S3 bucket. Pass to the ALB module as access_logs_bucket."
  value       = var.create_alb_logs_bucket ? aws_s3_bucket.alb_logs[0].bucket : null
}

output "alb_logs_bucket_arn" {
  description = "ARN of the ALB logs S3 bucket"
  value       = var.create_alb_logs_bucket ? aws_s3_bucket.alb_logs[0].arn : null
}

output "app_s3_policy_arn" {
  description = "ARN of the IAM policy granting app servers S3 access. Attach to the EC2 IAM role."
  value       = aws_iam_policy.app_s3_access.arn
}
