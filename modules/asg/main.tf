# ─────────────────────────────────────────────
#  Auto Scaling Group
#  Launches EC2 instances across private subnets
#  Registers them with the ALB target group
#  Replaces unhealthy instances automatically
# ─────────────────────────────────────────────
resource "aws_autoscaling_group" "this" {
  name                      = "${var.name}-asg"
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = var.launch_template_id
    version = "$Latest"
  }

  # Rolling instance refresh — zero-downtime deploys when launch template changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = var.instance_warmup
    }
    triggers = ["tag"]
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.name}-app-server" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
    
  lifecycle {
    create_before_destroy = true
    # Ignore desired_capacity after first apply — let the ASG manage it
    ignore_changes = [desired_capacity]
  }
}

# ─────────────────────────────────────────────
#  Scale Out Policy
#  Adds one instance when CPU is high
# ─────────────────────────────────────────────
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.this.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = var.scale_out_cooldown
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_out_cpu_threshold
  alarm_description   = "Trigger scale out when average CPU exceeds ${var.scale_out_cpu_threshold}%"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }

  tags = var.tags
}

# ─────────────────────────────────────────────
#  Scale In Policy
#  Removes one instance when CPU is low
# ─────────────────────────────────────────────
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.this.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = var.scale_in_cooldown
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_in_cpu_threshold
  alarm_description   = "Trigger scale in when average CPU drops below ${var.scale_in_cpu_threshold}%"
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }

  tags = var.tags
}
