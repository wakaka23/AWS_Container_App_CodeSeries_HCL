variable "common" {
  type = object({
    env = string
  })
}

variable "network" {
  type = object({
    private_subnet_for_db_ids = list(string)
    security_group_for_db_id  = string
  })
}

variable "db" {
  type = object({
    name                    = string
    db_master_user_name     = string
    db_master_user_password = string
  })
}
