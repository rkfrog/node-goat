variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "demo"
}

variable "db_password" {
  type      = string
  default   = "P@ssw0rd!demo"
  sensitive = false
}
