# ─────────────────────────────────────────────
#  Application Load Balancer
#  Internet-facing, placed in public subnets
# ─────────────────────────────────────────────
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2               = true
  drop_invalid_header_fields = true

  access_logs {
    bucket  = var.access_logs_bucket
    prefix  = "${var.name}-alb"
    enabled = var.access_logs_bucket != "" ? true : false
  }

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

# ─────────────────────────────────────────────
#  Target Group
#  ALB forwards traffic here; ASG registers
#  instances automatically
# ─────────────────────────────────────────────
resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }
  

  # Give in-flight requests time to complete before pulling an instance
  deregistration_delay = var.deregistration_delay

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = var.enable_stickiness
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name}-tg" })
}

# ─────────────────────────────────────────────
# HTTP Listener
# Always created
# Forwards traffic to target group
# ─────────────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }


  tags = merge(var.tags, { Name = "${var.name}-http-listener" })
}



# # ─────────────────────────────────────────────
# #  HTTPS Listener
# #  Only created when a certificate ARN is provided
# #  Forwards to the target group
# # ─────────────────────────────────────────────
# resource "aws_lb_listener" "https" {
#   count = var.certificate_arn != "" ? 1 : 0

#   load_balancer_arn = aws_lb.this.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = var.certificate_arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.this.arn
#   }

#   tags = merge(var.tags, { Name = "${var.name}-https-listener" })
# }