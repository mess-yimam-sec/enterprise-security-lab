# Enterprise Security Lab --- Documentation

This folder contains the technical documentation behind my Enterprise
Security Lab.

I am building the lab step by step rather than as a collection of
isolated AWS exercises. As I add new controls, I document what I built,
why I made certain security decisions, problems I ran into, and what I
learned while troubleshooting them.

If you are looking for the overall project and current status, start
with the [main project README](../README.md).

------------------------------------------------------------------------

## Identity and Authentication

Identity was one of the first areas I worked through because the rest of
the lab depends on having a secure way for users, tools, and workloads
to access AWS.

This part of the project covers IAM, MFA, STS, role assumption,
temporary credentials, and GitHub OIDC federation.

### Documentation

-   [GitHub OIDC → AWS Federation](./github-oidc-aws-federation.md)
-   [IAM Authentication
    Troubleshooting](./iam-authentication-troubleshooting.md)
-   [Identity and Authentication Session
    Summary](./identity-and-authentication-session-summary.md)
One of the main lessons from this work was learning to separate
**authentication, authorization, and trust**.

For example, giving an IAM role permissions is not enough by itself. The
trust relationship also has to define who is allowed to assume that
role.

That became especially important when GitHub Actions began
authenticating to AWS through OIDC.

------------------------------------------------------------------------

## Terraform and CI/CD

After establishing the identity foundation, I started managing the AWS
environment with Terraform and building a controlled GitHub workflow
around infrastructure changes.

Instead of treating Terraform as something I only run from my laptop,
the project is moving toward a workflow where infrastructure changes are
reviewed and validated before deployment.

The current flow is:

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

GitHub Actions authenticates to AWS using OIDC and receives temporary
credentials through AWS STS rather than relying on long-lived AWS access
keys stored in GitHub.

### Documentation

-   [Terraform CI/CD Validation](./terraform-cicd-validation.md)
-   [Terraform Infrastructure and Configuration](../terraform/README.md)

------------------------------------------------------------------------

## Infrastructure as Code

Terraform is being used to build the AWS infrastructure for the lab.

The current networking foundation includes:

VPC
└── Public Subnet
    ├── Route Table
    ├── Route Table Association
    ├── Internet Gateway
    └── Internet Route

Terraform state is stored remotely in Amazon S3 rather than being
committed to the repository.

The state configuration also uses S3 versioning and public-access
protection.

The next infrastructure work will build on this foundation with private
networking and additional network security controls.

For the Terraform-specific documentation and code structure, see:

[Terraform Infrastructure →](../terraform/README.md)

------------------------------------------------------------------------

## Secure Terraform Deployment

The Terraform deployment process is separated from the validation and
planning process.

The CI workflow can inspect and plan infrastructure changes, while the
Apply workflow uses a dedicated deployment role:

`EnterpriseSecurityLab-TerraformDeploy`

The deployment path currently looks like this:

GitHub Actions
      |
      v
GitHub OIDC
      |
      v
AWS STS
      |
      v
Temporary Credentials
      |
      v
Terraform Deployment Role
      |
      v
Terraform Apply
      |
      v
AWS Infrastructure

The Apply workflow also uses the protected `terraform-deploy` GitHub
environment so that deployment requires approval before Terraform is
allowed to make infrastructure changes.

This was an important step in moving the project from simply running
Terraform in CI to building a controlled deployment process.

------------------------------------------------------------------------

## Troubleshooting and Lessons Learned

I am intentionally keeping troubleshooting documentation as part of this
repository.

A large part of the learning has come from things that did not work the
first time.

Some of the issues I have worked through include:

-   AWS CLI authentication and expired sessions
-   IAM permissions and role assumption
-   MFA and temporary credentials
-   GitHub OIDC trust-policy failures
-   OIDC subject and audience claims
-   Terraform remote-state configuration
-   Git branch divergence after squash merges
-   Protected branch behavior
-   GitHub Actions YAML indentation and configuration errors
-   Separating Terraform Plan permissions from Apply permissions

I do not want this repository to show only the final working
configuration. Understanding why something failed and how I verified the
fix is part of the project.

------------------------------------------------------------------------

# Project Milestones

The milestone documents are shorter summaries of major stages of the
lab.

They are intended to show how the project is progressing without
requiring someone to read every troubleshooting or implementation
document.

## Milestone 2 --- Secure Terraform CI/CD

This milestone established the Terraform CI foundation.

It brought together GitHub Actions, AWS OIDC authentication, Terraform
validation and planning, remote state, pull requests, and protected
branch controls.

[Read Milestone 2 --- Secure Terraform
CI/CD](./milestone-2-secure-terraform-cicd.md)

## Milestone 3 --- Controlled Terraform Deployment

This milestone extended the CI foundation into controlled infrastructure
deployment.

It introduced a separate Terraform deployment role, AWS STS temporary
credentials, a protected GitHub deployment environment, approval before
deployment, and automated Terraform Apply.

[Read Milestone 3 --- Controlled Terraform
Deployment](./milestone-3-controlled-terraform-deployment.md)

------------------------------------------------------------------------

## Where I Am Going Next

The next phase of the lab is focused on **AWS network security**.

I plan to build the networking architecture incrementally rather than
adding everything at once.

The next areas include:

-   Private subnet architecture
-   Security Groups
-   Network ACLs
-   Controlled egress
-   VPC Flow Logs

After the networking foundation is stronger, the project will continue
into AWS security visibility and automation, including CloudTrail,
GuardDuty, Security Hub, centralized logging, KMS, Python security
automation, and incident-response workflows.

As each major stage is completed, I will add another milestone and link
it here.

------------------------------------------------------------------------

## Navigation

-   [← Enterprise Security Lab](../README.md)
-   [Terraform Infrastructure](../terraform/README.md)
-   [Milestone 2 --- Secure Terraform
    CI/CD](./milestone-2-secure-terraform-cicd.md)
-   [Milestone 3 --- Controlled Terraform
    Deployment](./milestone-3-controlled-terraform-deployment.md)
