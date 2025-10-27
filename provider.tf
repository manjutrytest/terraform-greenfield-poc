terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}
