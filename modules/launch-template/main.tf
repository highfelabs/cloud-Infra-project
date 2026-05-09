# ─────────────────────────────────────────────
#  Launch Template
#  Defines the blueprint for every EC2 instance
#  the ASG will launch. IMDSv2 enforced.
#  Encrypted gp3 root volume. No public IP.
# ─────────────────────────────────────────────
resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  # Attach to private subnet — no public IP ever
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_sg_id]
    delete_on_termination       = true
  }

  # IAM instance profile — attach only when provided
  dynamic "iam_instance_profile" {
    for_each = var.iam_instance_profile != "" ? [1] : []
    content {
      name = var.iam_instance_profile
    }
  }

  # Encrypted gp3 root volume
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # IMDSv2 — required, blocks SSRF-based credential theft
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Enable detailed CloudWatch monitoring
  monitoring {
    enabled = true
  }

  # User data script — optional
  user_data = base64encode(var.user_data)

  # Tag instances and volumes created by this template
  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-app-server" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.name}-app-volume" })
  }

  # Ensure new version exists before old one is destroyed during updates
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name}-lt" })
}
