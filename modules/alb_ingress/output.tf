output "alb_listener_ingress_arn" {
  value = aws_lb_listener.ingress.arn
}

output "alb_target_group_ingress_name" {
  value = aws_lb_target_group.ingress.name
}

output "alb_target_group_ingress_arn" {
  value = aws_lb_target_group.ingress.arn
}