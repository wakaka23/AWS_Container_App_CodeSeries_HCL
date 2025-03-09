########################
# VPC
########################

output "vpc_id" {
  value = aws_vpc.main.id
}

########################
# Subnet
########################

output "public_subnet_for_ingress_ids" {
  value = values(aws_subnet.public_ingress)[*].id
}

output "private_subnet_for_management_ids" {
  value = values(aws_subnet.private_management)[*].id
}

output "private_subnet_for_container_ids" {
  value = values(aws_subnet.private_container)[*].id
}

output "private_subnet_for_db_ids" {
  value = values(aws_subnet.private_db)[*].id
}

########################
# Security Group
########################

output "security_group_for_management_id" {
  value = aws_security_group.management.id
}

output "security_group_for_internal_alb_id" {
  value = aws_security_group.internal_alb.id
}

output "security_group_for_ingress_alb_id" {
  value = aws_security_group.ingress_alb.id
}

output "security_group_for_frontend_container_id" {
  value = aws_security_group.frontend.id
}

output "security_group_for_backend_container_id" {
  value = aws_security_group.backend.id
}

output "security_group_for_db_id" {
  value = aws_security_group.db.id
}

########################
# Route53 Public Hosted Zone
########################

output "public_hosted_zone_id" {
  value = data.aws_route53_zone.public.zone_id
}

output "public_hosted_zone_name" {
  value = data.aws_route53_zone.public.name
}
