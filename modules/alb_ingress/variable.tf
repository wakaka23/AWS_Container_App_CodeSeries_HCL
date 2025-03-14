variable "common" {
  type = object({
    env = string
  })
}

variable "network" {
  type = object({
    vpc_id    = string
    public_subnet_for_ingress_ids = list(string)
    security_group_for_ingress_alb_id = string
    public_hosted_zone_id = string
    public_hosted_zone_name = string
  })
}