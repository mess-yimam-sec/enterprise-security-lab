# Milestone 2: Secure Terraform CI/CD

**GitHub OIDC authentication + Terraform CI + Amazon S3 remote state**

## Purpose

This milestone documents how the Enterprise Security Lab connects GitHub Actions, AWS identity, Terraform, and remote state into one repeatable workflow.

## What was built

- GitHub Actions authenticates to AWS through GitHub OIDC instead of long-lived AWS access keys.
- AWS IAM trusts a scoped GitHub OIDC identity and issues temporary STS credentials.
- Terraform CI runs initialization, formatting, validation, and planning checks.
- Terraform state was migrated from the local workstation to an Amazon S3 backend.
- The S3 state bucket uses versioning and public-access blocking.
- Infrastructure changes move through feature branches, pull requests, checks, squash merges, and a protected `main` branch.

## Architecture at a glance

```text
Developer
  ↓
Feature branch
  ↓
Pull request
  ↓
GitHub Actions
  ├─ OIDC → AWS IAM role → STS temporary credentials
  └─ Terraform CI → init / fmt / validate / plan
  ↓
Amazon S3 remote state
  ↓
AWS infrastructure
```

## Why this matters

- **Identity:** OIDC avoids embedding long-lived AWS credentials in GitHub Actions.
- **Least privilege:** the CI role is intended to receive only the permissions required by the workflow.
- **State consistency:** remote state gives local Terraform and CI a shared source of truth.
- **Change control:** pull requests and protected `main` create a review point before infrastructure changes land.
- **Recoverability:** S3 versioning provides a history of state objects for recovery from accidental changes.

## Current implementation

| Component | Implementation |
|---|---|
| Identity | GitHub OIDC → AWS IAM role → STS temporary credentials |
| CI | GitHub Actions Terraform workflow |
| Terraform | AWS VPC networking and routing resources |
| State | Amazon S3 backend with versioning |
| Repository control | Feature branches, pull requests, protected `main`, squash merge |

## Lessons learned

- Terraform cannot rely on a developer's local AWS profile when it runs on a fresh GitHub runner.
- Remote state is part of the CI/CD security design, not just a storage convenience.
- Required status checks should be enforced only after the workflow reliably reports results for the intended PR event.
- Merge conflicts are a normal part of Git-based engineering and need deliberate resolution.

## Next step

Tighten the AWS permissions used by the GitHub OIDC Terraform role so remote-state access is explicitly scoped to the Terraform state bucket and infrastructure operations remain least-privilege.

## References

- Repository: https://github.com/mess-yimam-sec/enterprise-security-lab
- Terraform S3 backend: https://developer.hashicorp.com/terraform/language/backend/s3
- GitHub OIDC with AWS: https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
