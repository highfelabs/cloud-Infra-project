output "id" {
  description = "ID of the launch template. Pass to the ASG module."
  value       = aws_launch_template.this.id
}

output "name" {
  description = "Name of the launch template"
  value       = aws_launch_template.this.name
}

output "arn" {
  description = "ARN of the launch template"
  value       = aws_launch_template.this.arn
}

output "latest_version" {
  description = "Latest version number of the launch template. Useful for forcing instance refresh."
  value       = aws_launch_template.this.latest_version
}
