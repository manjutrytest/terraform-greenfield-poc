variable "aws_profile" {
  type    = string
  default = "default"
  description = "AWS CLI profile to use (must exist locally)"
}

variable "aws_region" {
  type    = string
  default = "eu-west-1"
  description = "AWS region to create resources in"
}

variable "project" {
  type    = string
  default = "tf-poc"
}
