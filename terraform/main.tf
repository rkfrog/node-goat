terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# DEMO ONLY: This file intentionally contains insecure configurations
# to demonstrate the JFrog Advanced Security IaC scanner. Do not use
# any of this in a real environment.
