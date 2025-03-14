########################
# ALB
########################

# Define ingress ALB
resource "aws_lb" "ingress" {
  name               = "${var.common.env}-alb-ingress"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.network.public_subnet_for_ingress_ids
  security_groups    = [var.network.security_group_for_ingress_alb_id]
  tags = {
    Name = "${var.common.env}-alb-ingress"
  }
}

# Define the listner for ingress ALB
resource "aws_lb_listener" "ingress" {
  load_balancer_arn = aws_lb.ingress.arn
  protocol          = "HTTPS"
  port              = "443"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.ingress.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress.arn
  }
}

# Define target group for ingress ALB
resource "aws_lb_target_group" "ingress" {
  name        = "${var.common.env}-tg-frontend"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.network.vpc_id
  health_check {
    protocol            = "HTTP"
    path                = "/healthcheck"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 15
    matcher             = 200
  }
}

########################
# Route53 Alias Record
########################

# Define Alias record for internal ALB
resource "aws_route53_record" "alb_ingress" {
  zone_id = var.network.public_hosted_zone_id
  name    = "www.${var.network.public_hosted_zone_name}"
  type    = "A"
  alias {
    name                   = aws_lb.ingress.dns_name
    zone_id                = aws_lb.ingress.zone_id
    evaluate_target_health = false
  }
}

########################
# ACM
########################

# Define ACM certificate
resource "aws_acm_certificate" "ingress" {
  domain_name       = "www.${var.network.public_hosted_zone_name}"
  validation_method = "DNS"
  tags = {
    Name = "${var.common.env}-acm-certificate"
  }
}

# Define Route53 record for ACM validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ingress.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = var.network.public_hosted_zone_id
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  type            = each.value.type
  ttl             = "300"
}