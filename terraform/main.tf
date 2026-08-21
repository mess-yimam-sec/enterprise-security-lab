terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.15.0"
}

provider "aws" {
  region = "us-east-1"
  profile = "mess-bg-lab-bootstrap"
}
resource "aws_vpc" "security_lab" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "enterprise-security-lab-vpc"
    Project = "enterprise-security-lab"
  }
}