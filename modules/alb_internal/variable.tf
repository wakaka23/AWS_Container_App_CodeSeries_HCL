variable "common" {
  type = object({
    env = string
    region = string
    account_id = string
  })
}

variable "network" {
  type = object({
    private_subnet_for_container_ids = list(string)
    security_group_for_internal_alb_id = string
    vpc_id = string
  })
}
