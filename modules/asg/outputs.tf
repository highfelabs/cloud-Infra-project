output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.this.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.this.arn
}

output "scale_out_policy_arn" {
  description = "ARN of the scale out policy"
  value       = aws_autoscaling_policy.scale_out.arn
}

output "scale_in_policy_arn" {
  description = "ARN of the scale in policy"
  value       = aws_autoscaling_policy.scale_in.arn
}

output "cpu_high_alarm_arn" {
  description = "ARN of the CloudWatch alarm that triggers scale out"
  value       = aws_cloudwatch_metric_alarm.cpu_high.arn
}

output "cpu_low_alarm_arn" {
  description = "ARN of the CloudWatch alarm that triggers scale in"
  value       = aws_cloudwatch_metric_alarm.cpu_low.arn
}
