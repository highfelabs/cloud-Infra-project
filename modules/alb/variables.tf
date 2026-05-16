variable "name" {
  description = "Name prefix for all ALB resources"
  type        = string
  default     = "saas-infra"
}

variable "vpc_id" {
  description = "VPC ID — required by the target group resource"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB. Must span at least 2 AZs. Output from the VPC module."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID to attach to the ALB. Output from the security-groups module."
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener. Leave empty to skip the HTTPS listener (not recommended for production)."
  type        = string
  default     = ""
}

variable "enable_deletion_protection" {
  description = "Prevent the ALB from being deleted via the AWS console or API. Set true for production."
  type        = bool
  default     = true
}

variable "access_logs_bucket" {
  description = "S3 bucket name to store ALB access logs. Leave empty to disable access logging."
  type        = string
  default     = ""
}

variable "app_port" {
  description = "Port the backend app servers listen on. The target group forwards traffic to this port."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "HTTP path the ALB uses to health-check instances. Must return 200-299."
  type        = string
  default     = "/health"
}

variable "deregistration_delay" {
  description = "Seconds the ALB waits before deregistering an instance — allows in-flight requests to complete."
  type        = number
  default     = 30
}

variable "enable_stickiness" {
  description = "Enable lb_cookie sticky sessions on the target group. Keep false unless session affinity is required."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all ALB resources"
  type        = map(string)
  default     = {}
}
