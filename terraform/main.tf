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
  region  = "us-east-1"
  #profile = "mess-bg-lab-bootstrap"
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

# adding a subnet and rounting table to the vpc resource #
resource "aws_subnet" "security_lab_public" {
  vpc_id                  = aws_vpc.security_lab.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "enterprise-security-lab-public-subnet"
    Project = "enterprise-security-lab"
  }
}

resource "aws_route_table" "security_lab_public" {
  vpc_id = aws_vpc.security_lab.id

  tags = {
    Name    = "enterprise-security-lab-public-rt"
    Project = "enterprise-security-lab"
  }
}

resource "aws_route_table_association" "security_lab_public" {
  subnet_id      = aws_subnet.security_lab_public.id
  route_table_id = aws_route_table.security_lab_public.id
}

resource "aws_internet_gateway" "security_lab" {
  vpc_id = aws_vpc.security_lab.id

  tags = {
    Name    = "enterprise-security-lab-igw"
    Project = "enterprise-security-lab"
  }
}

resource "aws_route" "security_lab_public_internet" {
  route_table_id         = aws_route_table.security_lab_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.security_lab.id
  # Managed by Terraform for the Enterprise Security Lab
}