variable "region" {
  default = "us-east-1"
}

variable "name" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "saas-infra"
}