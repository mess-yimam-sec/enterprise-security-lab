# Enterprise Security Lab

Here I want to show you what happens when you build a cloud environment with security in mind from the beginning?

This project is my hands-on **Enterprise Security Lab** — an evolving AWS environment where I am putting cloud security, identity, Infrastructure as Code, CI/CD, monitoring, automation, and incident response into practice.

Rather than building isolated demos, I’m connecting the pieces so that each layer supports the next one.

The project is intentionally being built in public, one milestone at a time.

## Where the project is today

The foundation is now in place.

I have built and tested:

* AWS IAM, MFA, and STS authentication
* IAM roles and least-privilege access
* GitHub Actions → AWS OIDC federation
* Terraform-managed AWS networking
* A protected `main` branch and pull-request workflow
* GitHub Actions Terraform CI
* Remote Terraform state in Amazon S3
* S3 versioning and public-access protection for Terraform state

The current focus is **secure Infrastructure as Code and cloud security engineering**.

## Start here

If you are new to the project, these are the best places to begin:

**Identity and CI/CD**

GitHub Actions authenticates to AWS through OIDC rather than storing long-lived AWS access keys.

**Infrastructure**

Terraform provisions and manages the AWS networking foundation.

**State management**

Terraform state is stored remotely in Amazon S3 with versioning and public-access protection.

**Git workflow**

Infrastructure changes move through feature branches, pull requests, automated checks, and a protected `main` branch.

## How the pieces fit together

```text
Developer
    |
    v
Feature Branch
    |
    v
Pull Request
    |
    v
GitHub Actions
    |
    +---- GitHub OIDC
    |         |
    |         v
    |      AWS IAM Role
    |         |
    |         v
    |   Temporary Credentials
    |
    +---- Terraform CI
              |
              +---- Init
              +---- Format
              +---- Validate
              +---- Plan
              |
              v
        Amazon S3 Remote State
              |
              v
        AWS Infrastructure
```

This is the part of the project I find most valuable: the security controls are connected instead of treated as separate exercises.

## A closer look at the current infrastructure

Terraform currently manages the first layer of AWS networking:

```text
VPC
└── Public Subnet
    ├── Route Table
    ├── Route Table Association
    ├── Internet Gateway
    └── Internet Route
```

This is the starting point for a larger network security design.

The next stages will introduce more restrictive network architecture, private resources, controlled egress, and additional visibility.

## Secure CI/CD

One of the first major security decisions in the lab was avoiding long-lived AWS credentials in GitHub Actions.

The workflow is:

```text
GitHub Actions
      |
      v
GitHub OIDC
      |
      v
AWS IAM OIDC Provider
      |
      v
Scoped IAM Role
      |
      v
STS Temporary Credentials
      |
      v
AWS APIs
```

The goal is simple: GitHub gets temporary credentials for the work it needs to perform instead of relying on permanent access keys.

This is also tied to the repository workflow:

```text
Feature Branch
      |
      v
Pull Request
      |
      v
Automated Terraform Checks
      |
      v
Review
      |
      v
Squash Merge
      |
      v
Protected main
```

## Why I am building this

I wanted a project that goes beyond learning individual AWS services or memorizing Terraform syntax.

The real goal is to understand how these areas work together:

```text
Identity
   +
Infrastructure
   +
Security
   +
CI/CD
   +
Monitoring
   +
Automation
   +
Incident Response
```

That means some of the most useful moments in this project have actually been the failures: broken trust policies, credential issues, Terraform state problems, branch conflicts, and CI failures.

Each one has become part of the learning process.

## Technology

| Area                   | Technology                                             |
| ---------------------- | ------------------------------------------------------ |
| Cloud                  | AWS                                                    |
| Infrastructure as Code | Terraform                                              |
| Identity               | IAM, STS, GitHub OIDC                                  |
| CI/CD                  | GitHub Actions                                         |
| Automation             | Python, PowerShell                                     |
| CLI                    | AWS CLI                                                |
| Version Control        | Git, GitHub                                            |
| Security               | IAM, CloudTrail, GuardDuty, Security Hub, VPC controls |

## Repository structure

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

The `docs/` directory will continue to grow as individual security controls, troubleshooting lessons, and architecture decisions are documented.

## What's next

The roadmap is intentionally incremental.

### Cloud infrastructure

* Private subnet architecture
* Controlled egress
* Security groups
* Network ACLs
* VPC Flow Logs

### AWS security

* CloudTrail
* GuardDuty
* Security Hub
* Centralized logging
* KMS encryption
* Additional least-privilege IAM roles

### Automation

* Python security automation
* Detection and response workflows
* Incident-response automation
* PowerShell AWS and Windows operations

### CI/CD

* Least-privilege Terraform state access
* Controlled Terraform deployment workflow
* Environment protection
* Separate permissions for validation and deployment

## Follow the build

This project is intentionally being developed incrementally.

The idea is not to jump straight to a finished architecture. Each milestone is implemented, tested, documented, and then carried forward into the next one.

If you are interested in cloud security, AWS, Terraform, IAM, or secure CI/CD, feel free to explore the repository, open an Issue, start a Discussion, or share an approach you would use differently.

**The project is still being built — and that is the point.**
