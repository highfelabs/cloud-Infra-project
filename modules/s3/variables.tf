variable "name" {
  description = "Name prefix for all S3 resources"
  type        = string
  default     = "saas-infra"

}

variable "bucket_suffix" {
  description = "Unique suffix appended to bucket names to ensure global uniqueness (e.g. AWS account ID or random string)"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for bucket encryption. Leave null to use AES256 (AWS-managed)."
  type        = string
  default     = null
}

variable "enable_versioning" {
  description = "Enable S3 versioning on the app bucket. Recommended for production."
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Days before non-current object versions are permanently deleted"
  type        = number
  default     = 90
}

variable "create_alb_logs_bucket" {
  description = "Whether to create a dedicated bucket for ALB access logs"
  type        = bool
  default     = true
}

variable "alb_logs_retention_days" {
  description = "Days to retain ALB access logs before expiration"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all S3 resources"
  type        = map(string)
  default     = {}
}
