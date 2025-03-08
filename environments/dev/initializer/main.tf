terraform {
  required_version = "~>1.10.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.81.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

module "initializer" {
  source = "../../../modules/initializer"
  bucket = {
    bucket_name = var.bucket.bucket_name
  }
}
