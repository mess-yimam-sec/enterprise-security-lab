# Milestone 3: Controlled Terraform Deployment

GitHub OIDC + protected deployment environment + Terraform Apply

## Purpose

This milestone extends the Enterprise Security Lab from Terraform validation and planning into controlled infrastructure deployment.

The goal is to allow GitHub Actions to apply Terraform changes to AWS using temporary credentials, a dedicated deployment role, and an approval gate instead of long-lived AWS access keys.

---- What was built-----

* A separate GitHub Actions workflow for Terraform deployment.
* A dedicated AWS IAM role: `EnterpriseSecurityLab-TerraformDeploy`.
* GitHub OIDC authentication to AWS STS for temporary deployment credentials.
* A protected GitHub environment named `terraform-deploy`.
* Manual approval before Terraform Apply can proceed.
* Terraform initialization against the existing Amazon S3 remote state.
* Automated `terraform apply` after approved changes reach the protected `main` branch.
* Separation between Terraform validation/planning and Terraform deployment permissions.

---- Work flow at a glance ------

Developer
  ↓
Feature branch
  ↓
Pull request
  ↓
Terraform CI
  ├─ fmt
  ├─ validate
  └─ plan
  ↓
Protected main
  ↓
terraform-deploy environment
  ↓
Deployment approval
  ↓
GitHub OIDC
  ↓
AWS STS
  ↓
EnterpriseSecurityLab-TerraformDeploy
  ↓
Temporary AWS credentials
  ↓
Terraform init / apply
  ↓
AWS infrastructure
/

---- Why this matters----

* Credential security: GitHub Actions does not require stored long-lived AWS access keys.
* Workload identity: GitHub OIDC allows AWS to verify the identity of the deployment workflow.
* Temporary access: AWS STS provides short-lived credentials for the deployment session.
* Separation of duties: Terraform planning and deployment use separate IAM roles.
* Deployment control: the `terraform-deploy` environment introduces an approval point before infrastructure changes are applied.
* Change control: infrastructure changes continue to move through feature branches, pull requests, checks, and protected `main`.
* State consistency: the deployment workflow uses the same Amazon S3 remote Terraform state as the rest of the project.

---- Current implementation----

| Component            | Implementation                                                  |
| -------------------- | --------------------------------------------------------------- |
| CI identity          | GitHub OIDC → AWS STS                                           |
| Terraform Plan role  | `EnterpriseSecurityLab-GitHubOIDC`                              |
| Terraform Apply role | `EnterpriseSecurityLab-TerraformDeploy`                         |
| Deployment control   | GitHub `terraform-deploy` environment                           |
| Approval             | Required before Terraform Apply                                 |
| Terraform state      | Amazon S3 remote backend                                        |
| Deployment           | GitHub Actions → Terraform Apply                                |
| Repository control   | Feature branches, pull requests, protected `main`, squash merge |

---- Lessons learned----

* A successful OIDC configuration depends on both IAM permissions and the role's trust relationship.
* GitHub environments affect the OIDC subject presented to AWS.
* Inspecting the actual OIDC claims is more useful than broadening permissions when troubleshooting federation failures.
* Temporary diagnostic steps should be removed after the identity problem is understood.
* Small YAML indentation or duplication errors can prevent a deployment workflow from running correctly.
* Squash merges can cause local and remote Git histories to diverge even when the intended changes have already reached `main`.
* Deployment permissions should be separated from validation permissions rather than giving every CI workflow infrastructure-changing access.

----- Result-----

The lab now has a controlled Terraform deployment path:

**Pull request → Terraform Plan → protected main → deployment approval → GitHub OIDC → AWS STS → deployment role → Terraform Apply**

This completes the CI/CD deployment foundation and provides a controlled path for future infrastructure changes.

----- Project journey-----

* Previous: Milestone 2 --- Secure Terraform CI/CD: https://github.com/mess-yimam-sec/enterprise-security-lab/blob/main/docs/milestone-2-secure-terraform-cicd.md
* Current: Milestone 3 — Controlled Terraform Deployment: https://github.com/mess-yimam-sec/enterprise-security-lab/blob/main/docs/milestone-3-controlled-terraform-deployment.md
* Next: Milestone 4 — AWS Network Security

---- Next step----

I will Extend the Terraform-managed AWS network with security-focused architecture, including private subnets, Security Groups, Network ACLs, controlled egress, and VPC Flow Logs.
---- References----

* https://github.com/mess-yimam-sec/enterprise-security-lab/blob/main/README.md
* Secure Terraform CI/CD:  https://github.com/mess-yimam-sec/enterprise-security-lab/blob/main/docs/milestone-2-secure-terraform-cicd.md
* GitHub Actions OIDC with AWS: https://github.com/mess-yimam-sec/enterprise-security-lab/blob/main/docs/github-oidc-aws-federation.md
* Terraform S3 backend:  https://github.com/mess-yimam-sec/enterprise-security-lab/blob/main/README.md

