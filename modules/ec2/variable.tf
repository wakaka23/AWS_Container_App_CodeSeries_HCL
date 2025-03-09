variable "common" {
  type = object({
    env = string
  })
}

variable "network" {
  type = object({
    vpc_id                            = string
    private_subnet_for_management_ids = list(string)
    security_group_for_management_id  = string
  })
}
