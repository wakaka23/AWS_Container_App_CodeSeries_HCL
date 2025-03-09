variable "common" {
  type = object({
    env = string
    region = string
  })
}

variable "public_hosted_zone" {
  type = object({
    domain_name = string
  })
}

variable "network" {
  type = object({
    cidr = string
    public_subnets_for_ingress = list(object({
      az = string
      cidr = string
    }))
    private_subnets_for_container = list(object({
      az = string
      cidr = string
    }))
    private_subnets_for_db = list(object({
      az = string
      cidr = string
    }))
    private_subnets_for_management = list(object({
      az = string
      cidr = string
    }))
    private_subnets_for_vpn = list(object({
      az = string
      cidr = string
    }))
    client_vpn_cidr = string
  })
}
