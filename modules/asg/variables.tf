variable "name" {
  description = "Name prefix for the ASG and related resources"
  type        = string
  default     = "saas-infra"

}

variable "private_subnet_ids" {
  description = "Private subnet IDs the ASG will launch instances into. Output from the VPC module."
  type        = list(string)
}

variable "launch_template_id" {
  description = "ID of the launch template the ASG will use. Output from the launch-template module."
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group instances will be registered with. Output from the ALB module."
  type        = string
}

variable "min_size" {
  description = "Minimum number of running instances"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of running instances"
  type        = number
  default     = 6
}

variable "desired_capacity" {
  description = "Initial desired instance count. Ignored after first apply — the ASG manages this value."
  type        = number
  default     = 3
}

variable "health_check_grace_period" {
  description = "Seconds to wait after an instance launches before the ASG starts checking its health"
  type        = number
  default     = 120
}

variable "instance_warmup" {
  description = "Seconds to wait before counting a new instance as healthy during a rolling instance refresh"
  type        = number
  default     = 120
}

variable "scale_out_cpu_threshold" {
  description = "CPU utilization percentage that triggers a scale out event (add one instance)"
  type        = number
  default     = 70
}

variable "scale_in_cpu_threshold" {
  description = "CPU utilization percentage that triggers a scale in event (remove one instance)"
  type        = number
  default     = 30
}

variable "scale_out_cooldown" {
  description = "Seconds to wait between consecutive scale out events"
  type        = number
  default     = 300
}

variable "scale_in_cooldown" {
  description = "Seconds to wait between consecutive scale in events"
  type        = number
  default     = 300
}

variable "tags" {
  description = "Tags applied to the ASG and propagated to all launched instances"
  type        = map(string)
  default     = {}
}
