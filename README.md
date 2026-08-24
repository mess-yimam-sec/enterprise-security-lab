

\# Enterprise Security Lab



A hands-on cloud security engineering lab focused on AWS identity, infrastructure, secure CI/CD, monitoring, automation, and incident response.



The project is designed to demonstrate how security controls work together across the full cloud engineering lifecycle, from identity and infrastructure provisioning to CI/CD and incident response.



\## Project Status



Active development



\### Completed milestones



\* AWS IAM, MFA, and STS authentication

\* IAM roles and least-privilege access

\* GitHub Actions → AWS OIDC federation

\* Terraform-based AWS VPC networking

\* Public subnet, route table, Internet Gateway, and routing

\* Protected `main` branch with pull-request workflow

\* GitHub Actions Terraform CI

\* Terraform remote state using Amazon S3

\* S3 versioning and public-access protection for Terraform state



\### Current focus



Cloud Security Engineering and secure Infrastructure as Code



\## Architecture



```text

Developer

&#x20;  |

&#x20;  v

Feature Branch

&#x20;  |

&#x20;  v

Pull Request

&#x20;  |

&#x20;  v

GitHub Actions

&#x20;  |

&#x20;  +---- GitHub OIDC

&#x20;  |         |

&#x20;  |         v

&#x20;  |      AWS IAM Role

&#x20;  |         |

&#x20;  |         v

&#x20;  |    Temporary AWS Credentials

&#x20;  |

&#x20;  +---- Terraform CI

&#x20;            |

&#x20;            +---- Terraform Init

&#x20;            +---- Terraform Format

&#x20;            +---- Terraform Validate

&#x20;            +---- Terraform Plan

&#x20;            |

&#x20;            v

&#x20;       Amazon S3 Remote State

&#x20;            |

&#x20;            v

&#x20;       AWS Infrastructure

```



\## Security Focus



This lab emphasizes practical cloud-security engineering rather than isolated tool usage.



Key areas include:



\* Identity and access management

\* MFA and temporary AWS credentials

\* IAM roles and least privilege

\* GitHub OIDC federation

\* Secure CI/CD authentication

\* Infrastructure as Code

\* Terraform remote state

\* Network segmentation

\* Logging and monitoring

\* Security automation

\* Incident response



\## Technology Stack



| Area                   | Technologies                                      |

| ---------------------- | ------------------------------------------------- |

| Cloud                  | AWS                                               |

| Infrastructure as Code | Terraform                                         |

| Identity               | AWS IAM, STS, GitHub OIDC                         |

| CI/CD                  | GitHub Actions                                    |

| Automation             | Python, PowerShell                                |

| CLI                    | AWS CLI                                           |

| Version Control        | Git, GitHub                                       |

| Security               | CloudTrail, GuardDuty, Security Hub, VPC controls |

| Operating Systems      | Windows, Linux                                    |



\## Repository Structure



```text

enterprise-security-lab/

├── .github/

│   └── workflows/

│       ├── aws-oidc-test.yml

│       └── terraform.yml

│

├── terraform/

│   ├── main.tf

│   ├── variables.tf

│   ├── outputs.tf

│   └── .terraform.lock.hcl

│

├── docs/

│   └── ...

│

└── README.md

```



\## Current Terraform Infrastructure



The Terraform configuration currently manages:



```text

VPC

└── Public Subnet

&#x20;   ├── Route Table

&#x20;   ├── Route Table Association

&#x20;   └── Internet Gateway Route

```



Terraform state is stored remotely in Amazon S3 with versioning and public-access protection enabled.



\## CI/CD Security Model



GitHub Actions does not use long-lived AWS access keys.



Instead:



```text

GitHub Actions

&#x20;     |

&#x20;     v

GitHub OIDC

&#x20;     |

&#x20;     v

AWS IAM OIDC Provider

&#x20;     |

&#x20;     v

Scoped IAM Role

&#x20;     |

&#x20;     v

STS Temporary Credentials

&#x20;     |

&#x20;     v

AWS API

```



This reduces the need to store long-lived AWS credentials in GitHub and allows the workflow to authenticate using short-lived credentials.



\## Git Workflow



The repository uses a protected `main` branch.



Changes follow:



```text

Feature Branch

&#x20;     |

&#x20;     v

Commit

&#x20;     |

&#x20;     v

Pull Request

&#x20;     |

&#x20;     v

Terraform CI

&#x20;     |

&#x20;     v

Review / Checks

&#x20;     |

&#x20;     v

Squash Merge

&#x20;     |

&#x20;     v

main

```



\## Roadmap



\### Cloud Infrastructure



\* Private subnet architecture

\* NAT and controlled egress

\* Security groups

\* Network ACLs

\* VPC Flow Logs



\### AWS Security



\* CloudTrail

\* GuardDuty

\* Security Hub

\* Centralized logging

\* KMS encryption

\* Additional least-privilege IAM roles



\### Automation



\* Python security automation

\* Incident detection

\* Incident-response workflows

\* PowerShell AWS/Windows operational automation



\### CI/CD



\* Terraform plan as a required pull-request check

\* Controlled Terraform deployment workflow

\* Environment protection

\* Least-privilege deployment roles



\## Project Philosophy



The goal is not simply to learn individual AWS or DevOps tools.



The goal is to understand how:



```text

Identity

&#x20;  +

Infrastructure

&#x20;  +

Security

&#x20;  +

CI/CD

&#x20;  +

Automation

&#x20;  +

Monitoring

&#x20;  +

Incident Response

```



fit together to form a practical cloud security engineering workflow.



\## Follow the Project



The project is developed incrementally, with infrastructure changes reviewed through GitHub pull requests.



Questions, ideas, and architectural feedback are welcome through GitHub Issues and Discussions.
CI validation checkpoint


