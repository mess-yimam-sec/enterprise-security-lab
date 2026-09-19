terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.15.0"
  backend "s3" {
    bucket       = "enterprise-security-lab-tfstate-149957954264"
    key          = "terraform/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"

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

# Private route table
resource "aws_route_table" "security_lab_private" {
  vpc_id = aws_vpc.security_lab.id

  tags = {
    Name    = "enterprise-security-lab-private-rt"
    Project = "enterprise-security-lab"
  }
}

resource "aws_route_table_association" "security_lab_private" {
  subnet_id      = aws_subnet.security_lab_private.id
  route_table_id = aws_route_table.security_lab_private.id
}

# Private subnet
resource "aws_subnet" "security_lab_private" {
  vpc_id                  = aws_vpc.security_lab.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name    = "enterprise-security-lab-private-subnet"
    Project = "enterprise-security-lab"
  }
}

# Security group for private resources
resource "aws_security_group" "security_lab_private" {
  name        = "enterprise-security-lab-private-sg"
  description = "Security group for private subnet resources"
  vpc_id      = aws_vpc.security_lab.id

  ingress {
    description = "Allow internal VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.10.0.0/16"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "enterprise-security-lab-private-sg"
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

# Network ACL for the private subnet
resource "aws_network_acl" "security_lab_private" {
  vpc_id = aws_vpc.security_lab.id

  tags = {
    Name    = "enterprise-security-lab-private-nacl"
    Project = "enterprise-security-lab"
  }
}

# Associate the private subnet with the private NACL
resource "aws_network_acl_association" "security_lab_private" {
  network_acl_id = aws_network_acl.security_lab_private.id
  subnet_id      = aws_subnet.security_lab_private.id
}

# Allow inbound traffic from within the VPC
resource "aws_network_acl_rule" "security_lab_private_inbound_vpc" {
  network_acl_id = aws_network_acl.security_lab_private.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "10.10.0.0/16"
  from_port      = 0
  to_port        = 0
}

# Allow outbound traffic to within the VPC
resource "aws_network_acl_rule" "security_lab_private_outbound_vpc" {
  network_acl_id = aws_network_acl.security_lab_private.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "10.10.0.0/16"
  from_port      = 0
  to_port        = 0
}
# Add cloudwatch flow logs
resource "aws_cloudwatch_log_group" "security_lab_vpc_flow_logs" {
  name              = "/enterprise-security-lab/vpc-flow-logs"
  retention_in_days = 3

  tags = {
    Name    = "enterprise-security-lab-vpc-flow-logs"
    Project = "enterprise-security-lab"
  }
}
# aws_iam_role for vpv_flow_logs
resource "aws_iam_role" "security_lab_vpc_flow_logs" {
  name = "EnterpriseSecurityLab-VPCFlowLogs"

  tags = {
    Name    = "enterprise-security-lab-vpc-flow-logs"
    Project = "enterprise-security-lab"
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}
# IAM Role permission policy
resource "aws_iam_role_policy" "security_lab_vpc_flow_logs" {
  name = "EnterpriseSecurityLab-VPCFlowLogs-CloudWatch"

  role = aws_iam_role.security_lab_vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"

        ]

        Resource = "*"
      }
    ]
  })
}
#Aws_aws_flow_log

resource "aws_flow_log" "security_lab_private" {
  subnet_id    = aws_subnet.security_lab_private.id
  traffic_type = "ALL"

  iam_role_arn         = aws_iam_role.security_lab_vpc_flow_logs.arn
  log_destination      = aws_cloudwatch_log_group.security_lab_vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"

  max_aggregation_interval = 600

  tags = {
    Name    = "enterprise-security-lab-private-flow-log"
    Project = "enterprise-security-lab"
  }
}

