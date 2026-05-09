output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB. Create a Route 53 alias record pointing here."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB. Required when creating a Route 53 alias record."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group. Pass to the ASG module so it can register instances."
  value       = aws_lb_target_group.this.arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.this.name
}

output "http_listener_arn" {
  description = "ARN of the HTTP redirect listener"
  value       = aws_lb_listener.http.arn
}

# output "https_listener_arn" {
#   description = "ARN of the HTTPS listener. Null if no certificate_arn was provided."
#   value       = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : null
# }
