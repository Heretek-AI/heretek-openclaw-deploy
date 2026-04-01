# ==============================================================================
# Heretek OpenClaw - AWS Application Load Balancer Configuration
# ==============================================================================
# ALB for OpenClaw traffic routing and SSL termination
# ==============================================================================

# ------------------------------------------------------------------------------
# ALB Security Group
# ------------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

# ------------------------------------------------------------------------------
# Application Load Balancer
# ------------------------------------------------------------------------------

resource "aws_lb" "openclaw" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = var.alb_deletion_protection
  enable_http2               = true
  drop_invalid_header_fields = true
  idle_timeout               = 60

  access_logs {
    bucket  = aws_s3_bucket.alb_logs[0].bucket
    prefix  = "alb-logs"
    enabled = var.environment == "prod"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })

  depends_on = [aws_internet_gateway.openclaw]
}

# ------------------------------------------------------------------------------
# S3 Bucket for ALB Access Logs
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "alb_logs" {
  count = var.environment == "prod" ? 1 : 0

  bucket = "${local.name_prefix}-alb-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-logs"
  })
}

resource "aws_s3_bucket_policy" "alb_logs" {
  count = var.environment == "prod" ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowALBLogDelivery"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  count = var.environment == "prod" ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  count = var.environment == "prod" ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

# ------------------------------------------------------------------------------
# HTTP Listener (Redirect to HTTPS)
# ------------------------------------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.openclaw.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ------------------------------------------------------------------------------
# HTTPS Listener
# ------------------------------------------------------------------------------

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.openclaw.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }

  lifecycle {
    ignore_changes = [certificate_arn]
  }
}

# ------------------------------------------------------------------------------
# Target Groups
# ------------------------------------------------------------------------------

# OpenClaw Gateway Target Group
resource "aws_lb_target_group" "gateway" {
  name     = "${local.name_prefix}-gateway"
  port     = 18789
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-299"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false
  }

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-gateway"
    Component   = "gateway"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# LiteLLM Proxy Target Group
resource "aws_lb_target_group" "litellm" {
  name     = "${local.name_prefix}-litellm"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-299"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-litellm"
    Component   = "litellm"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# Listener Rules
# ------------------------------------------------------------------------------

# Route to LiteLLM based on path
resource "aws_lb_listener_rule" "litellm" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.litellm.arn
  }

  condition {
    path_pattern {
      values = ["/v1/*", "/litellm/*"]
    }
  }
}

# Route to Gateway for WebSocket connections
resource "aws_lb_listener_rule" "gateway_websocket" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }

  condition {
    path_pattern {
      values = ["/ws/*", "/gateway/*"]
    }
  }
}

# ------------------------------------------------------------------------------
# ALB IAM Role for S3 Logging
# ------------------------------------------------------------------------------

resource "aws_iam_service_linked_role" "alb" {
  aws_service_name = "elasticloadbalancing.amazonaws.com"

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# ACM Certificate (Optional - if not provided)
# ------------------------------------------------------------------------------

resource "aws_acm_certificate" "openclaw" {
  count = var.acm_certificate_arn == null ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = var.subject_alternative_names

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-certificate"
  })
}

resource "aws_acm_certificate_validation" "openclaw" {
  count = var.acm_certificate_arn == null ? 1 : 0

  certificate_arn         = aws_acm_certificate.openclaw[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.acm_certificate_arn == null ? {
    for dvo in aws_acm_certificate.openclaw[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# ------------------------------------------------------------------------------
# Route53 DNS Records
# ------------------------------------------------------------------------------

resource "aws_route53_record" "openclaw" {
  count = var.acm_certificate_arn == null ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.openclaw.dns_name
    zone_id                = aws_lb.openclaw.zone_id
    evaluate_target_health = true
  }
}
