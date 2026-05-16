variable "name" {
  description = "Name prefix for the launch template"
  type        = string
  default     = "saas-infra"

}

variable "ami_id" {
  description = "AMI ID to use for EC2 instances. Use a data source in the env to keep this dynamic."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for app servers"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access. Leave empty to omit and rely on SSM only (recommended)."
  type        = string
  default     = ""
}

variable "app_sg_id" {
  description = "Security group ID to attach to each instance. Output from the security-groups module."
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name to attach. Should include AmazonSSMManagedInstanceCore policy."
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 8
}

variable "user_data" {
  description = "launch script"
  type = string
}

variable "tags" {
  description = "Tags applied to the launch template and propagated to instances and volumes"
  type        = map(string)
  default     = {}
}
