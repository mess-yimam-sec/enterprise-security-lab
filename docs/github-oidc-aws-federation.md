# GitHub Actions → AWS OIDC Federation Runbook

## Purpose

This document records the practical GitHub Actions → AWS OIDC federation exercise completed in the Enterprise Security Lab.

The goal was to replace long-lived AWS credentials in GitHub Actions with short-lived AWS credentials obtained through:

```text
GitHub Actions
      ↓
GitHub OIDC token
      ↓
AWS IAM OIDC Provider
      ↓
IAM Role trust policy
      ↓
AWS STS
      ↓
temporary AWS credentials
      ↓
AWS API
```

This document is intended as a GitHub repository reference, troubleshooting guide, and continuation point for later Terraform/CI/CD work.

> **Security rule:** Never store AWS access keys, secret access keys, session tokens, passwords, MFA secrets, or other long-lived credentials in GitHub Actions.

---

# 1. Final architecture

```text
┌──────────────────────────┐
│ GitHub Repository        │
│ mess-yimam-sec/          │
│ enterprise-security-lab │
└────────────┬─────────────┘
             │
             │ GitHub Actions workflow
             ▼
┌──────────────────────────┐
│ GitHub OIDC              │
│ token.actions...         │
└────────────┬─────────────┘
             │
             │ JWT / OIDC token
             ▼
┌──────────────────────────┐
│ AWS IAM OIDC Provider    │
│ token.actions.github...  │
└────────────┬─────────────┘
             │
             │ trust policy
             ▼
┌──────────────────────────┐
│ IAM Role                 │
│ EnterpriseSecurityLab-   │
│ GitHubOIDC               │
└────────────┬─────────────┘
             │
             │ AssumeRoleWithWebIdentity
             ▼
┌──────────────────────────┐
│ AWS STS                  │
│ Temporary credentials    │
└────────────┬─────────────┘
             │
             ▼
       AWS API / VPC
```

---

# 2. What federation means

Federation does not require many applications.

The essential relationship is:

```text
Identity provider
        ↕
Trusted service
```

In this lab:

```text
GitHub
  ↓
AWS
```

GitHub manages the workload identity.

AWS trusts GitHub's OIDC identity provider.

The GitHub workflow does not need to have an IAM user in AWS.

---

# 3. OAuth 2.0 vs OIDC vs STS

## OAuth 2.0

OAuth 2.0 is an authorization framework.

In the earlier `aws login` experiment, AWS used a browser-based OAuth flow.

Observed debug output included:

```text
Waiting for auth code at
http://127.0.0.1:<port>/oauth/callback
```

That was part of the OAuth authorization flow.

## OIDC

OpenID Connect adds an identity layer on top of OAuth 2.0.

For GitHub Actions, the important idea is:

```text
GitHub:
"I am this specific workflow/repository identity."
```

GitHub signs the identity information in a JWT.

AWS validates the token and evaluates the IAM role trust policy.

## STS

AWS Security Token Service provides temporary AWS credentials.

The GitHub federation flow uses:

```text
AssumeRoleWithWebIdentity
```

to obtain temporary credentials.

Simple mental model:

```text
OAuth 2.0
→ authorization framework

OIDC
→ identity assertion

STS
→ temporary AWS credentials
```

---

# 4. Starting state

Before the OIDC work:

```text
IAM users
├── mess-bg-lab
│
IAM roles
└── EnterpriseSecurityLab-VPCReadOnly
│
Identity providers
└── empty
```

The account had no OIDC identity provider configured.

---

# 5. Create the AWS IAM OIDC provider

Open:

```text
AWS Console
→ IAM
→ Identity providers
→ Add provider
```

Select:

```text
Provider type:
OpenID Connect (OIDC)
```

Use:

```text
Provider URL:
https://token.actions.githubusercontent.com
```

Use:

```text
Audience:
sts.amazonaws.com
```

Tags were left empty because they are optional for this exercise.

After creation, AWS displayed:

```text
token.actions.githubusercontent.com added
```

The provider exists, but an IAM role must trust the provider before it can be used.

---

# 6. Why the provider is not enough

The OIDC provider answers:

> Which external identity issuer does AWS trust?

It does not answer:

> Which GitHub identities may assume which AWS role?

That decision belongs in the IAM role trust policy.

The architecture is therefore:

```text
OIDC Provider
    ↓
Role Trust Policy
    ↓
STS
```

---

# 7. Create the GitHub OIDC role

The role created was:

```text
EnterpriseSecurityLab-GitHubOIDC
```

The AWS role was created using the Web identity trust option.

The configured GitHub identity provider was:

```text
token.actions.githubusercontent.com
```

The audience was:

```text
sts.amazonaws.com
```

---

# 8. Role permissions

The GitHub role was intentionally given limited VPC read permissions.

Inline policy name:

```text
EnterpriseSecurityLab-GitHubOIDCPolicy
```

Permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups"
      ],
      "Resource": "*"
    }
  ]
}
```

The role was not given `AdministratorAccess`, and no long-lived AWS credential was placed in GitHub.

---

# 9. Tags

The role was tagged with:

```text
Project = enterprise-security-lab
Purpose = github-oidc
```

Tags are not part of the authentication decision. They are metadata for organization and identification.

---

# 10. Initial GitHub repository scope

The GitHub repository is:

```text
mess-yimam-sec/enterprise-security-lab
```

The initial AWS console setup used:

```text
GitHub owner:
mess-yimam-sec

Repository:
enterprise-security-lab

Branch:
left blank for the first proof of concept
```

Leaving the branch blank allowed the federation relationship to be tested before hardening the trust policy.

---

# 11. Initial trust policy generated by AWS

The initial trust policy was similar to:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": [
            "sts.amazonaws.com"
          ]
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:mess-yimam-sec/enterprise-security-lab:*",
            "repo:mess-yimam-sec/enterprise-security-lab:*"
          ]
        }
      }
    }
  ]
}
```

The AWS wizard generated the same subject pattern twice. The duplicate value did not broaden the trust, so the role was created. The trust policy was later replaced with a precise condition based on the actual GitHub claims.

---

# 12. Create the GitHub Actions workflow

The workflow file was:

```text
.github/
└── workflows/
    └── aws-oidc-test.yml
```

Workflow:

```yaml
name: AWS OIDC Test

on:
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  test-aws-oidc:
    runs-on: ubuntu-latest

    steps:
      - name: Configure AWS credentials with OIDC
        uses: aws-actions/configure-aws-credentials@v6.2.3
        with:
          role-to-assume: arn:aws:iam::ACCOUNT-ID:role/EnterpriseSecurityLab-GitHubOIDC
          aws-region: us-east-1

      - name: Verify AWS identity
        run: aws sts get-caller-identity

      - name: Test VPC read access
        run: aws ec2 describe-vpcs
```

---

# 13. Why `id-token: write` is required

This section is critical:

```yaml
permissions:
  id-token: write
  contents: read
```

`id-token: write` allows the workflow to request a GitHub OIDC token.

It does not mean:

```text
GitHub has AWS permissions
```

Instead:

```text
GitHub can request an identity token
        ↓
AWS validates that token
        ↓
AWS decides whether the role trusts it
```

The AWS permissions still come from the IAM role.

---

# 14. YAML troubleshooting

An intermediate workflow version failed because the diagnostic shell step was incomplete.

Problem:

```yaml
run: |
```

with no properly indented commands below it.

Correct syntax:

```yaml
run: |
  echo "repository=${{ github.repository }}"
  echo "owner_id=${{ github.repository_owner_id }}"
  echo "repo_id=${{ github.repository_id }}"
  echo "ref=${{ github.ref }}"
```

After fixing the indentation, GitHub accepted the workflow.

---

# 15. First OIDC failure

The first workflow run reached the AWS credentials step but failed with:

```text
Could not assume role with OIDC:
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

This was important because:

```text
GitHub workflow ✓
OIDC token request ✓
AWS OIDC provider ✓
AWS role lookup ✓
Role assumption ✗
```

The problem was therefore in the **role trust conditions**, not the workflow's AWS access-key configuration.

---

# 16. Inspect the GitHub claims

A temporary diagnostic step was added:

```yaml
- name: Show GitHub repository information
  run: |
    echo "repository=${{ github.repository }}"
    echo "owner_id=${{ github.repository_owner_id }}"
    echo "repo_id=${{ github.repository_id }}"
    echo "ref=${{ github.ref }}"
```

The successful diagnostic output was:

```text
repository=mess-yimam-sec/enterprise-security-lab
owner_id=314676558
repo_id=1327860875
ref=refs/heads/main
```

These values were the key to diagnosing the trust-policy mismatch.

---

# 17. GitHub OIDC immutable subject format

The repository used the newer immutable subject format.

The subject that needed to be trusted was:

```text
repo:mess-yimam-sec@314676558/enterprise-security-lab@1327860875:ref:refs/heads/main
```

This was the important difference from the older pattern:

```text
repo:mess-yimam-sec/enterprise-security-lab:*
```

The role initially trusted the older subject style, so AWS rejected the GitHub OIDC token.

---

# 18. Final role trust policy

The GitHub OIDC role trust policy was changed to:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT-ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:mess-yimam-sec@314676558/enterprise-security-lab@1327860875:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

The effective trust now limits the role to:

```text
GitHub owner:
mess-yimam-sec

Owner ID:
314676558

Repository:
enterprise-security-lab

Repository ID:
1327860875

Branch:
main

Audience:
sts.amazonaws.com
```

---

# 19. Successful OIDC workflow

After updating the trust policy, the GitHub Actions workflow completed successfully.

The workflow contained:

```text
1. Configure AWS credentials with OIDC
2. Verify AWS identity
3. Test VPC read access
```

The GitHub Actions run showed a green check.

This proved that:

```text
GitHub
  ↓
OIDC token
  ↓
AWS OIDC Provider
  ↓
Trust policy matched
  ↓
AssumeRoleWithWebIdentity
  ↓
AWS STS
  ↓
temporary credentials
```

---

# 20. Verify AWS identity result

The workflow ran:

```bash
aws sts get-caller-identity
```

The result contained:

```text
UserId
Account
Arn
```

The most important field for this exercise was the ARN.

It identified the role session in this general form:

```text
arn:aws:sts::ACCOUNT-ID:assumed-role/EnterpriseSecurityLab-GitHubOIDC/...
```

That proves the GitHub workflow was operating as the IAM role rather than using:

```text
arn:aws:iam::ACCOUNT-ID:user/mess-bg-lab
```

---

# 21. VPC permission validation

The workflow then ran:

```bash
aws ec2 describe-vpcs
```

This validated the role's VPC read permissions.

The full chain was therefore proven:

```text
GitHub identity
      ↓
OIDC authentication
      ↓
IAM trust decision
      ↓
STS role session
      ↓
role permissions
      ↓
EC2/VPC API
      ↓
SUCCESS
```

---

# 22. Comparison with the earlier IAM-user approach

## Earlier manual approach

```text
IAM User
   ↓
Access Key + Secret
   ↓
TOTP
   ↓
STS
   ↓
temporary credentials
```

This requires a long-lived credential somewhere as the bootstrap source.

## GitHub OIDC approach

```text
GitHub Actions
   ↓
OIDC token
   ↓
AWS OIDC Provider
   ↓
IAM Role
   ↓
STS
   ↓
temporary credentials
```

No long-lived AWS access key is required by the GitHub workflow.

This is the key security improvement.

---

# 23. What OIDC did and did not do

OIDC did:

```text
Identify the GitHub workload
        ↓
Allow AWS to trust that external identity
```

OIDC did not:

```text
grant administrator permissions
```

The AWS permissions still came from:

```text
EnterpriseSecurityLab-GitHubOIDC
```

Therefore:

```text
OIDC
= identity/federation

IAM role policy
= AWS authorization

STS
= temporary credentials
```

---

# 24. Security boundaries in the final design

The trust policy has two important checks.

## Audience

```text
token.actions.githubusercontent.com:aud
=
sts.amazonaws.com
```

This ensures the token is intended for AWS STS.

## Subject

```text
token.actions.githubusercontent.com:sub
=
repo:mess-yimam-sec@314676558/enterprise-security-lab@1327860875:ref:refs/heads/main
```

This limits which GitHub repository/branch identity may assume the role.

---

# 25. No AWS secrets in GitHub

The workflow deliberately contains no:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
```

The only AWS identity reference in the workflow is the role ARN:

```yaml
role-to-assume: arn:aws:iam::ACCOUNT-ID:role/EnterpriseSecurityLab-GitHubOIDC
```

An IAM role ARN is not a secret.

---

# 26. Troubleshooting checklist

When GitHub OIDC fails with:

```text
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

check these in order:

```text
1. Workflow has:
   id-token: write

2. OIDC provider exists:
   token.actions.githubusercontent.com

3. Provider audience is:
   sts.amazonaws.com

4. Workflow role ARN is correct

5. Role trust policy:
   Principal = GitHub OIDC provider

6. Trust policy aud claim matches:
   sts.amazonaws.com

7. Trust policy sub claim matches
   GitHub's actual subject format

8. Repository owner/repository IDs are correct

9. Branch/ref matches the intended GitHub workflow

10. Role permissions allow the AWS API action
```

Do not solve the problem by adding:

```text
AdministratorAccess
```

or by removing the subject restriction.

---

# 27. Useful GitHub diagnostic values

The diagnostic workflow exposed:

```text
repository=${{ github.repository }}
owner_id=${{ github.repository_owner_id }}
repo_id=${{ github.repository_id }}
ref=${{ github.ref }}
```

These values are useful when debugging OIDC subject mismatches.

Do not print the actual OIDC token itself.

---

# 28. Useful PowerShell / Git commands

## Check workflow status locally

```powershell
git status
```

## Stage workflow

```powershell
git add .github/workflows/aws-oidc-test.yml
```

## Commit workflow

```powershell
git commit -m "Add GitHub Actions AWS OIDC test"
```

## Push workflow

```powershell
git push origin main
```

## Open workflow file locally

```powershell
code .github\workflows\aws-oidc-test.yml
```

## Display workflow file

```powershell
Get-Content .github\workflows\aws-oidc-test.yml
```

---

# 29. Final architecture checkpoint

The Enterprise Security Lab now has two working STS-based patterns.

## IAM user → role

```text
mess-bg-lab
      ↓
MFA / temporary user session
      ↓
sts:AssumeRole
      ↓
EnterpriseSecurityLab-VPCReadOnly
      ↓
temporary role credentials
      ↓
VPC read access
```

## GitHub OIDC → role

```text
GitHub Actions
      ↓
GitHub OIDC JWT
      ↓
AWS OIDC Provider
      ↓
EnterpriseSecurityLab-GitHubOIDC
      ↓
sts:AssumeRoleWithWebIdentity
      ↓
temporary role credentials
      ↓
VPC read access
```

The second architecture is the target pattern for CI/CD.

---

# 30. Next module

The next logical step is to use the working OIDC role for the actual infrastructure pipeline:

```text
GitHub Actions
      ↓
OIDC
      ↓
AWS IAM Role
      ↓
temporary credentials
      ↓
Terraform
      ↓
AWS VPC
```

A future hardening phase can evaluate:

```text
GitHub environment protections
branch protection
pull-request vs main deployment
Terraform plan/apply separation
least-privilege Terraform role
state management
CloudTrail validation
```

The existing OIDC proof-of-concept should remain the baseline before introducing Terraform deployment permissions.

---

# 31. Final result

The lab successfully demonstrated:

```text
✓ GitHub OIDC provider created
✓ GitHub-specific IAM role created
✓ Repository/branch trust configured
✓ GitHub OIDC token requested
✓ AWS validated the OIDC trust
✓ STS AssumeRoleWithWebIdentity succeeded
✓ Temporary AWS credentials issued
✓ AWS identity verified
✓ VPC read access verified
✓ No long-lived AWS key stored in GitHub
```

This completes the foundational GitHub Actions → AWS OIDC federation exercise.
