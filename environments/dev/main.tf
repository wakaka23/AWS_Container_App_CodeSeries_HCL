terraform {
  required_version = ">=1.10.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.81.0"
    }
  }
  backend "s3" {
    encrypt = true
  }
}

module "network" {
  source             = "../../modules/network"
  common             = local.common
  network            = local.network
  public_hosted_zone = var.public_hosted_zone
}

module "ec2" {
  source  = "../../modules/ec2"
  common  = local.common
  network = module.network
}

module "ecr" {
  source = "../../modules/ecr"
  common = local.common
}
