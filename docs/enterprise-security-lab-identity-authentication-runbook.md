# Enterprise Security Lab — IAM Authentication, TOTP, STS, and IAM Role Runbook

## Purpose

This document records the practical IAM troubleshooting and identity work completed before the OAuth/OIDC and networking portions of the Enterprise Security Lab. It is designed as a daily reference, troubleshooting runbook, and GitHub learning artifact.

> **Security rule:** Never commit AWS access keys, secret access keys, MFA secrets, QR codes, session tokens, passwords, downloaded AWS credential CSV files, or `~/.aws/credentials` to GitHub.

---

# 1. Final architecture we built

```text
                         AWS ACCOUNT
                              │
                     ┌────────▼────────┐
                     │  mess-bg-lab    │
                     │    IAM User     │
                     └────────┬────────┘
                              │
                       password + TOTP
                              │
                              ▼
                    temporary STS session
                              │
                       sts:AssumeRole
                              │
                              ▼
              ┌──────────────────────────────┐
              │ EnterpriseSecurityLab-      │
              │ VPCReadOnly IAM Role        │
              └──────────────┬───────────────┘
                             │
                        STS role session
                             │
                             ▼
                 assumed-role/... identity
                             │
                             ▼
                    VPC read-only access
```

The successful identity transition was:

```text
arn:aws:iam::ACCOUNT:user/mess-bg-lab
              │
              │ AssumeRole
              ▼
arn:aws:sts::ACCOUNT:assumed-role/EnterpriseSecurityLab-VPCReadOnly/SESSION
```

---

# 2. Environment baseline

```text
Operating system: Windows 11
AWS CLI:          2.36.21
Default region:   us-east-1
AWS lab user:     mess-bg-lab
GitHub identity:  mess-yimam-sec
Repository:       enterprise-security-lab
```

---

# 3. IAM user and group design

## IAM user

```text
mess-bg-lab
```

This is the normal interactive AWS lab identity. Root is reserved for account-level administration.

## IAM group

```text
CloudLab-PowerUser
```

Final intended relationship:

```text
mess-bg-lab
      │
      ▼
CloudLab-PowerUser
      │
      ├── PowerUserAccess
      ├── SignInLocalDevelopmentAccess
      └── EnterpriseSecurityLab-AssumeReadOnlyRole
```

The user also has `IAMUserChangePassword` directly attached.

---

# 4. IAM console authorization issue

While using `mess-bg-lab` in the IAM console, AWS displayed:

```text
Access denied to iam:ListUsers
Access denied to iam:GetUser
```

This demonstrated:

```text
Authentication = Who are you?
Authorization  = What are you allowed to do?
```

The user is intentionally not an IAM administrator. We did **not** add `AdministratorAccess` just to make IAM console pages display correctly.

The `iam:GetUser` denial remains expected under the current least-privilege design because `PowerUserAccess` excludes broad IAM actions.

---

# 5. Group-membership troubleshooting — root cause of the EC2 problem

A major troubleshooting discovery was that the `CloudLab-PowerUser` group showed:

```text
Users in this group (0)
```

even though earlier views had suggested that `mess-bg-lab` was associated with the group.

The actual missing configuration was group membership.

## Fix

Using an administrative/root session:

```text
IAM
 → User groups
 → CloudLab-PowerUser
 → Users
 → Add users
 → mess-bg-lab
```

After the correction:

```text
Users in this group (1)

mess-bg-lab
```

The group policies then became effective for the user.

## Validation

After refreshing temporary credentials:

```powershell
aws ec2 describe-vpcs --profile mess-bg-lab-bootstrap --region us-east-1
```

successfully returned the VPC information.

### Lesson

A policy attached to a group is only useful to a user when the user is actually a member of that group.

---

# 6. MFA configuration

Two MFA methods were configured for `mess-bg-lab`:

```text
Passkeys and security keys
Virtual MFA / TOTP
```

The existing passkey was retained.

A virtual authenticator app was added and successfully verified in the AWS Management Console.

Target model:

```text
Passkey
   └── normal AWS Console authentication

TOTP
   └── CLI-compatible MFA workflow
```

---

# 7. `aws login` troubleshooting

We tested:

```powershell
aws login
```

and:

```powershell
aws login --remote
```

The CLI was confirmed as:

```text
aws-cli/2.36.21
```

The browser flow repeatedly ended with:


```text
Authentication failed
Invalid request
```

Debug output included:

```text
Waiting for auth code at
http://127.0.0.1:<port>/oauth/callback
```

The local callback flow did not reliably complete, and `--remote` did not resolve the problem.

The group also contained `SignInLocalDevelopmentAccess`, whose inspected JSON was:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "signin:AuthorizeOAuth2Access",
        "signin:CreateOAuth2Token"
      ],
      "Resource": "arn:aws:signin:*:*:oauth2/public-client/*"
    }
  ]
}
```

### Decision

Because the `aws login` flow remained unreliable in this setup, we stopped spending time on it and moved to the IAM-user + TOTP + STS temporary-credentials workflow.

---

# 8. OAuth 2.0 — where it appeared

The `aws login` path is where OAuth 2.0 appeared in this lab.

Simplified flow:

```text
AWS CLI
   │
   │ OAuth authorization request
   ▼
AWS Sign-In
   │
   ▼
Browser
   │
   │ username + password + MFA
   ▼
Authorization
   │
   │ authorization code
   ▼
127.0.0.1:<port>/oauth/callback
   │
   ▼
AWS CLI
   │
   │ token exchange
   ▼
temporary AWS credentials
```

The debug line waiting for the localhost callback was practical evidence that this browser/OAuth flow was in use.

---

# 9. OIDC — not implemented yet

OIDC was discussed but not implemented in this stage.

Planned future flow:

```text
GitHub Actions
      │
      │ OIDC token / JWT
      ▼
GitHub OIDC Provider
      │
      │ AssumeRoleWithWebIdentity
      ▼
AWS STS
      │
      ▼
IAM Role
      │
      ▼
temporary AWS credentials
      │
      ▼
Terraform
      │
      ▼
AWS
```

Simple distinction:

```text
OAuth 2.0
"What can this application obtain access to?"

OIDC
"Who is this authenticated identity?"
+
"What can it access?"
```

---

# 10. Long-lived bootstrap credentials

An existing Access Key 1 for `mess-bg-lab` was found. It was newly created for the lab and had not been used before this work.

The downloaded credentials file contained both:

```text
Access Key ID
Secret Access Key
```

No second access key was created.

A dedicated source profile was created:

```text
mess-bg-lab-longterm
```

Verification:

```powershell
aws configure list --profile mess-bg-lab-longterm
aws sts get-caller-identity --profile mess-bg-lab-longterm
```

The long-lived profile is treated as a **bootstrap-only** credential source.

---

# 11. Temporary STS credentials

A second profile was used for temporary credentials:

```text
mess-bg-lab-bootstrap
```

Successful flow:

```text
mess-bg-lab-longterm
      │
      │ Access Key + Secret
      ▼
AWS STS
      │
      │ Virtual MFA ARN + TOTP
      ▼
temporary credentials
      │
      ▼
mess-bg-lab-bootstrap
```

The successful command was:

```powershell
aws configure mfa-login --profile mess-bg-lab-longterm
```

The **Virtual MFA ARN** and current TOTP code were used.

The session was configured for a longer active-lab duration:

```text
129600 seconds = 36 hours
```

Important:

> A 36-hour STS session is still temporary. It expires by design.

---

# 12. Expired-token problem and workaround

A temporary session eventually expired. Trying to use the expired temporary profile as the source for a new session produced:

```text
ExpiredToken
The security token included in the request is expired
```

The correct pattern was:

```text
mess-bg-lab-longterm
      │
      │ valid long-lived source
      ▼
TOTP
      │
      ▼
fresh temporary STS session
      │
      ▼
mess-bg-lab-bootstrap
```

Do not use an already-expired temporary session as the bootstrap source for obtaining a new session.

---

# 13. EC2/VPC authorization issue and final resolution

An EC2/VPC test initially returned `AccessDenied` for:

```text
ec2:DescribeVpcs
```

Some attempts were also affected by expired temporary credentials, which initially made the diagnosis confusing.

After checking the IAM group relationship, the actual configuration problem was found:

```text
CloudLab-PowerUser
Users in this group (0)
```

The user was added correctly to the group.

After refreshing the STS session, this command succeeded:

```powershell
aws ec2 describe-vpcs --profile mess-bg-lab-bootstrap --region us-east-1
```

### Final root cause

The EC2/VPC authorization failure was caused by the user's group membership not being effective, not because `PowerUserAccess` was incapable of EC2 access.

---

# 14. IAM Role exercise

We created:

```text
EnterpriseSecurityLab-VPCReadOnly
```

The role has a small VPC read-only inline policy, covering actions such as:

```text
ec2:DescribeVpcs
ec2:DescribeSubnets
ec2:DescribeRouteTables
ec2:DescribeSecurityGroups
```

Role permissions answer:

> What can the role do?

---

# 15. Role trust policy

The role trust policy was changed to trust the specific IAM user:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT-ID:user/mess-bg-lab"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

This answers:

> Who does the role trust?

---

# 16. Identity permission to assume the role

The group received an inline policy:

```text
EnterpriseSecurityLab-AssumeReadOnlyRole
```

Final policy pattern:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::ACCOUNT-ID:role/EnterpriseSecurityLab-VPCReadOnly"
    }
  ]
}
```

This answers:

> Is `mess-bg-lab` allowed to request this exact role?

The two sides must match:

```text
IDENTITY SIDE
CloudLab-PowerUser
      │
      └── sts:AssumeRole
          Resource = exact role ARN

TRUST SIDE
EnterpriseSecurityLab-VPCReadOnly
      │
      └── Principal = mess-bg-lab
```

---

# 17. Role-name mismatch troubleshooting

A troubleshooting mistake occurred because two different names were used:

Actual role:

```text
EnterpriseSecurityLab-VPCReadOnly
```

But the AssumeRole permission temporarily referenced:

```text
EnterpriseSecurityLab-ReadOnly
```

This produced `AccessDenied` because the exact target role ARN did not match.

The policy and CLI profile were corrected to use:

```text
EnterpriseSecurityLab-VPCReadOnly
```

This was a practical lesson in exact ARN matching.

---

# 18. Successful AssumeRole validation

The role-based CLI profile was configured with the source profile and exact role ARN.

Verification:

```powershell
aws sts get-caller-identity --profile mess-bg-lab-role
```

returned an ARN containing:

```text
assumed-role/EnterpriseSecurityLab-VPCReadOnly/...
```

This proved that the CLI successfully operated through an STS-assumed role.

The identity transition was:

```text
Before
arn:aws:iam::ACCOUNT:user/mess-bg-lab

After
arn:aws:sts::ACCOUNT:assumed-role/EnterpriseSecurityLab-VPCReadOnly/SESSION
```

---

# 19. Role permission validation

Using the role profile:

```powershell
aws ec2 describe-vpcs --profile mess-bg-lab-role --region us-east-1
```

successfully returned VPC information.

That proved:

```text
IAM user
   ↓
AssumeRole
   ↓
STS temporary role credentials
   ↓
EnterpriseSecurityLab-VPCReadOnly
   ↓
VPC read permissions
   ↓
SUCCESS
```

---

# 20. Why the role assumption did not ask for another MFA code

The role trust policy did not require an MFA condition.

The sequence was:

```text
mess-bg-lab
   │
   │ already authenticated with TOTP
   ▼
valid temporary user session
   │
   │ sts:AssumeRole
   ▼
role session
```

Therefore a second MFA prompt was not required.

A future hardening exercise can require MFA in the role trust policy using `aws:MultiFactorAuthPresent`.

---

# 21. Simple mental model

```text
AUTHENTICATION
"Who are you?"
        │
        ▼
mess-bg-lab + MFA
        │
        ▼
AUTHORIZATION
"What can you do?"
        │
        ▼
IAM policies / group membership
        │
        ▼
STS
"Give me temporary credentials."
        │
        ▼
IAM ROLE
"What role am I operating as?"
        │
        ▼
assumed-role/...
```

---

# 22. OAuth 2.0 vs. OIDC vs. STS

| Technology | Used now? | Practical use in the lab |
|---|---|---|
| OAuth 2.0 | Yes, encountered | `aws login` browser authorization flow |
| TOTP MFA | Yes | MFA for IAM-user CLI temporary credentials |
| STS | Yes | Temporary user sessions and `AssumeRole` |
| IAM Role | Yes | `EnterpriseSecurityLab-VPCReadOnly` |
| OIDC | Not yet | Future GitHub Actions → AWS federation |

The key idea is:

```text
OAuth 2.0
→ delegated authorization / application access

OIDC
→ identity layer built on OAuth

STS
→ AWS temporary credentials

IAM Role
→ trusted identity + permissions for temporary access
```

---

# 23. Planned next module — GitHub OIDC

Target architecture:

```text
GitHub Actions
      │
      │ OIDC JWT
      ▼
GitHub OIDC Provider
      │
      │ AssumeRoleWithWebIdentity
      ▼
AWS STS
      │
      ▼
IAM Role
      │
      ▼
temporary credentials
      │
      ▼
Terraform
      │
      ▼
AWS
```

The security goal is:

```text
No long-lived AWS access key stored in GitHub Actions
```

---

# 24. Practical PowerShell reference

## Check the long-lived source profile

```powershell
aws configure list --profile mess-bg-lab-longterm
```

## Check the temporary user profile

```powershell
aws configure list --profile mess-bg-lab-bootstrap
```

## Check current AWS identity

```powershell
aws sts get-caller-identity --profile mess-bg-lab-bootstrap
```

## Refresh temporary user credentials for the active lab session

```powershell
aws configure mfa-login `
  --profile mess-bg-lab-longterm `
  --update-profile mess-bg-lab-bootstrap `
  --duration-seconds 129600
```

## Configure the role profile

```powershell
aws configure set role_arn arn:aws:iam::ACCOUNT-ID:role/EnterpriseSecurityLab-VPCReadOnly --profile mess-bg-lab-role
aws configure set source_profile mess-bg-lab-longterm --profile mess-bg-lab-role
aws configure set region us-east-1 --profile mess-bg-lab-role
```

## Verify the assumed role identity

```powershell
aws sts get-caller-identity --profile mess-bg-lab-role
```

## Test role VPC permissions

```powershell
aws ec2 describe-vpcs --profile mess-bg-lab-role --region us-east-1
```

---

# 25. Troubleshooting decision tree

```text
                    AWS CLI command
                           │
                           ▼
                 Are the credentials valid?
                      /           \
                    NO             YES
                    │               │
             NoCredentials /       ▼
             ExpiredToken      Is the action allowed?
                                   /       \
                                 NO         YES
                                 │           │
                           inspect IAM       command
                           policies/groups   proceeds
```

For `AssumeRole`:

```text
                    sts:AssumeRole
                          │
                ┌─────────┴─────────┐
                ▼                   ▼
        Caller identity policy   Role trust policy
        sts:AssumeRole           Principal
                │                   │
                └─────────┬─────────┘
                          ▼
                    both must allow
                          │
                          ▼
                         STS
```

---

# 26. Key lessons learned

1. Authentication and authorization are different.
2. A group policy is not effective unless the user is actually a member of the group.
3. Do not answer `AccessDenied` by automatically granting AdministratorAccess.
4. Long-lived credentials and temporary STS credentials serve different purposes.
5. Temporary credentials expire by design.
6. Use a valid long-lived source when refreshing an expired temporary session.
7. IAM roles have both permissions and trust.
8. A caller needs permission to assume a role, and the role must trust that caller.
9. Role ARNs must match exactly.
10. STS role assumption changes the operating identity to an `assumed-role` session.
11. OAuth 2.0 and OIDC are different concepts.
12. OIDC will be the next federation exercise using GitHub Actions.

---

# 27. Current checkpoint

```text
AWS CLI 2.36.21                     ✓
Region: us-east-1                   ✓

mess-bg-lab IAM user                ✓
Passkey MFA                         ✓
Virtual TOTP MFA                    ✓

CloudLab-PowerUser membership       ✓
PowerUserAccess                     ✓
SignInLocalDevelopmentAccess        ✓
AssumeRole permission               ✓

Long-lived bootstrap profile        ✓
Temporary STS user credentials      ✓
IAM Role                            ✓
Role trust policy                   ✓
STS AssumeRole                      ✓
assumed-role ARN                    ✓
VPC read through role               ✓

aws login browser/OAuth path        unresolved / not used
IAM GetUser                         intentionally denied
OIDC                                next module
GitHub Actions → AWS                next module
```

## Next session

Resume from the **IAM Role + STS** checkpoint. Do not redo the IAM troubleshooting.

Next planned exercise:

```text
IAM Role + STS
      ↓
OAuth 2.0 review
      ↓
OIDC / JWT
      ↓
GitHub Actions OIDC provider
      ↓
AWS IAM trust policy
      ↓
STS AssumeRoleWithWebIdentity
      ↓
Terraform with temporary AWS credentials
```
