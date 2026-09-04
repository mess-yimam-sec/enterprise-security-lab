# Terraform --- Enterprise Security Lab
This directory contains the Terraform configuration used to build and manage the AWS infrastructure for the Enterprise Security Lab.

The infrastructure is being developed incrementally. I am starting with a simple networking foundation, then adding security controls and more
restrictive architecture as the project progresses.

## Current Infrastructure

Terraform currently manages the first layer of the AWS network in `us-east-1`.
The current architecture is:
VPC
10.10.0.0/16
│
├── Internet Gateway
│
└── Public Subnet
    10.10.1.0/24
    us-east-1a
    │
    └── Public Route Table
         │
         └── 0.0.0.0/0
              │
              └── Internet Gateway
The public subnet is configured to assign public IP addresses automatically.
This is the starting point for the larger network security design that will be added later.
------------------------------------------------------------------------
## Terraform Files

### `main.tf`
This file currently contains the full Terraform configuration.
It defines:
-   Terraform and AWS provider requirements
-   Amazon S3 remote backend
-   AWS provider configuration
-   VPC
-   Public subnet
-   Route table
-   Route table association
-   Internet Gateway
-   Default internet route

### `variables.tf`
This file is currently empty. It is reserved for future input variables as the Terraform configuration
becomes more reusable and configurable.

### `outputs.tf`
This file is currently empty.It is reserved for future outputs such as VPC IDs, subnet IDs, route
table IDs, and other useful resource information.
------------------------------------------------------------------------
## Terraform Requirements
The configuration currently requires:
terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

The AWS provider is configured for: Region: us-east-1
------------------------------------------------------------------------
## Remote State
Terraform state is stored remotely in Amazon S3.
Current backend configuration:
backend "s3" {
  bucket       = "enterprise-security-lab-tfstate-149957954264"
  key          = "terraform/terraform.tfstate"
  region       = "us-east-1"
  use_lockfile = true
}
Remote state is used instead of keeping the Terraform state file in the repository.
The S3 backend also uses Terraform state locking through:
use_lockfile = true

The state bucket is configured separately with versioning and
public-access protection.
------------------------------------------------------------------------
## Current Resources
The current Terraform configuration creates the following AWS resources:
  Resource                  Purpose
  ------------------------- ---------------------------------------------------
  VPC                       Main network for the Enterprise Security Lab
  Public Subnet             Public network segment inside the VPC
  Route Table               Controls routing for the public subnet
  Route Table Association   Associates the subnet with the route table
  Internet Gateway          Provides internet connectivity to the VPC
  Internet Route            Sends `0.0.0.0/0` traffic to the Internet Gateway
------------------------------------------------------------------------
## Network Configuration
### VPC

CIDR: 10.10.0.0/16 /This is just sample IP blocks
DNS support and DNS hostnames are enabled.
### Public Subnet
CIDR: 10.10.1.0/24
Availability Zone: us-east-1a
Public IP assignment: enabled

### Internet Routing
The public route table contains a default route:
Destination: 0.0.0.0/0
Target: Internet Gateway
This gives resources in the public subnet a path to the internet when
the resource itself has the required networking configuration.
------------------------------------------------------------------------
## Resource Tagging
The Terraform resources use consistent project tagging.
Example:
tags = {
  Name    = "enterprise-security-lab-vpc"
  Project = "enterprise-security-lab"
}
This makes the resources easier to identify and manage inside AWS.
------------------------------------------------------------------------
## Deployment Workflow
Terraform is not intended to be deployed directly from an uncontrolled
local process.
Infrastructure changes move through the project workflow:

Feature Branch
      |
      v
Pull Request
      |
      v
Terraform Validation / Plan
      |
      v
Review
      |
      v
Protected main
      |
      v
Deployment Approval
      |
      v
Terraform Apply
GitHub Actions authenticates to AWS through GitHub OIDC and AWS STS.
This allows the workflows to use temporary AWS credentials instead of
storing long-lived AWS access keys in GitHub.

Terraform Plan and Terraform Apply also use separate IAM roles so that
validation permissions and deployment permissions remain separated.
------------------------------------------------------------------------
## Security Approach
The Terraform configuration is intentionally being expanded in stages.
The current public subnet is a foundation, not the final network
security architecture.
The next stages will introduce more restrictive controls and additional
visibility.
Planned areas include:
-   Private subnet architecture
-   Security Groups
-   Network ACLs
-   Controlled egress
-   VPC Flow Logs
  
As those controls are added, the Terraform configuration and this
documentation will be updated together.
------------------------------------------------------------------------
## Related Documentation
For the wider security design and CI/CD implementation, see:

-   [Enterprise Security Lab](../README.md)
-   [Project Documentation](../docs/README.md)
-   [Terraform CI/CD Validation](../docs/terraform-cicd-validation.md)
-   [Milestone 2 --- Secure Terraform
    CI/CD](../docs/milestone-2-secure-terraform-cicd.md)
-   [Milestone 3 --- Controlled Terraform
    Deployment](../docs/milestone-3-controlled-terraform-deployment.md)
