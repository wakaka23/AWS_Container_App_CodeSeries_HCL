variable "common" {
  type = object({
    env        = string
    account_id = string
  })
}

variable "network" {
  type = object({
    vpc_id                                   = string
    private_subnet_for_container_ids         = list(string)
    security_group_for_frontend_container_id = string
  })
}

variable "alb_ingress" {
  type = object({
    alb_target_group_ingress_arn = string
  })
}

variable "alb_internal" {
  type = object({
    alb_internal_dns_name = string
  })
}

variable "secrets_manager" {
  type = object({
    secret_for_db_arn = string
  })
}