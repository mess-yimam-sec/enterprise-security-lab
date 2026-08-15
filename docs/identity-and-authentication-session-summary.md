# Enterprise Security Lab — Identity & Authentication Session Summary

## Project
**GitHub:** `mess-yimam-sec/enterprise-security-lab`

**Project principle:** Build → Automate → Secure → Validate → Document

## Session objective

Before moving into VPC and Terraform work, we established a working understanding of IAM users/groups, authentication vs. authorization, passkey vs. TOTP MFA, AWS CLI authentication, OAuth-based `aws login`, long-lived IAM access keys vs. temporary STS credentials, and the foundation for IAM roles, OAuth, and OIDC.

## AWS CLI baseline

- Windows 11
- AWS CLI `2.36.21`
- Lab region: `us-east-1`
- Repository: `enterprise-security-lab`

Initial state:

```text
aws sts get-caller-identity
→ NoCredentials
```

## Lab IAM identity

Dedicated AWS lab user:

```text
mess-bg-lab
```

GitHub identity is separate:

```text
mess-yimam-sec
```

Root is reserved for account-level administration, not normal Terraform, CLI, Python/boto3, or lab operations.

## IAM group and policies

The lab user belongs to:

```text
CloudLab-PowerUser
```

The group has:

```text
PowerUserAccess
SignInLocalDevelopmentAccess
```

The user also has:

```text
IAMUserChangePassword
```

directly attached.

### PowerUserAccess

Inspected JSON:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "NotAction": [
        "iam:*",
        "organizations:*",
        "account:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "account:GetAccountInformation",
        "account:GetGovCloudAccountInformation",
        "account:GetPrimaryEmail",
        "account:ListRegions",
        "iam:CreateServiceLinkedRole",
        "iam:DeleteServiceLinkedRole",
        "iam:ListRoles",
        "organizations:DescribeEffectivePolicy",
        "organizations:DescribeOrganization"
      ],
      "Resource": "*"
    }
  ]
}
```

Lesson:

> `PowerUserAccess` is not AdministratorAccess. It intentionally excludes broad IAM, Organizations, and Account actions.

### SignInLocalDevelopmentAccess

Inspected JSON:

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

This policy is attached through the group and is intended to support the AWS CLI browser/OAuth sign-in workflow.

## IAM console authorization issue

While using `mess-bg-lab` in the IAM console, we saw:

```text
Access denied to iam:ListUsers
Access denied to iam:GetUser
```

This demonstrates:

> Authentication proves who you are; authorization determines what you can do.

The lab user is intentionally not an IAM administrator. We did not add AdministratorAccess merely to make IAM console pages work.

## MFA configuration

The IAM user has two MFA methods:

```text
Passkeys and security keys
Virtual MFA / TOTP
```

The passkey was retained.

A virtual authenticator app was added and successfully verified in the AWS Management Console.

Target model:

```text
Passkey
  → Console authentication

TOTP
  → CLI-compatible MFA workflow
```

## `aws login` troubleshooting

We tested:

```powershell
aws login
```

and:

```powershell
aws login --remote
```

CLI version was confirmed as:

```text
aws-cli/2.36.21
```

The browser flow repeatedly ended with:

```text
Authentication failed
Invalid request
```

The normal local flow also showed:

```text
Waiting for auth code at http://127.0.0.1:<port>/oauth/callback
```

`--remote` did not resolve the problem.

Current conclusion:

> The browser-based `aws login` path is not reliable for this account/device setup, despite correct CLI version, working IAM console login, working TOTP, and the correct `SignInLocalDevelopmentAccess` policy.

We therefore moved to the IAM-user + TOTP + STS temporary-credentials workflow.

## Long-lived bootstrap credentials

An existing Access Key 1 for `mess-bg-lab` was found.

Facts established:

- Created during this lab work
- Never previously used
- Access Key ID and Secret Access Key were available in the downloaded credentials file
- No second access key was created

Two profiles were deliberately separated:

```text
mess-bg-lab-longterm
→ long-lived bootstrap credentials

mess-bg-lab-bootstrap
→ temporary STS credentials
```

The long-lived profile successfully passed:

```powershell
aws sts get-caller-identity --profile mess-bg-lab-longterm
```

This confirmed that the long-lived credentials themselves are valid.

## Temporary STS credentials

Successful flow:

```text
mess-bg-lab-longterm
    ↓
Access Key ID + Secret Access Key
    ↓
Virtual MFA ARN + TOTP
    ↓
STS GetSessionToken
    ↓
Temporary credentials
    ↓
mess-bg-lab-bootstrap
```

AWS returned an expiration time.

This proved:

- access key works
- TOTP works
- STS works
- temporary credentials can be issued
- CLI can use the temporary session

The long-lived credential is the bootstrap mechanism; the temporary session is intended for normal lab API activity.

## Temporary credential expiration

The temporary session later expired.

Trying to refresh using the expired temporary profile produced:

```text
ExpiredToken
```

The fix was to use:

```text
mess-bg-lab-longterm
```

as the source profile when generating a new session, writing the refreshed temporary credentials into:

```text
mess-bg-lab-bootstrap
```

Lesson:

> Do not use an expired temporary session as the bootstrap source for obtaining a new session. Use the valid long-lived source plus MFA.

## Temporary session duration

We discussed using:

```powershell
--duration-seconds 129600
```

which is 36 hours, the maximum for the IAM-user GetSessionToken workflow.

This is more convenient for an active personal lab, but the exposure window is longer. Temporary sessions still expire.

Long term, the lab should move toward IAM Roles and federation instead of relying on manual access-key-to-TOTP bootstrap sessions.

## EC2/VPC authorization test

A fresh temporary session was used to test:

```powershell
aws ec2 describe-vpcs --profile mess-bg-lab-bootstrap --region us-east-1
```

At one point the request failed because the session was expired, which initially obscured the authorization result.

After refreshing the session, the EC2 request still returned an authorization error:

```text
mess-bg-lab is not authorized to perform:
ec2:DescribeVpcs
because no identity-based policy allows the ec2:DescribeVpcs action
```

This requires further investigation with a fresh session before changing policies.

Do **not** add broad EC2 or Administrator permissions just to make the error disappear.

## Permissions boundary and Organizations checks

Established:

```text
Permissions boundary: Not set
```

The AWS account appears to be a standalone account, not a member of an AWS Organization.

No Organization should be created merely for troubleshooting.

These checks reduce the likelihood of a permissions boundary or SCP explaining the EC2 denial.

## OAuth and OIDC concepts introduced

### OAuth 2.0

Primarily an authorization/delegation protocol:

> What may this application access?

### OIDC

An identity layer built on OAuth 2.0:

> Who is the authenticated identity?

OIDC commonly uses JWTs.

### AWS STS

Provides temporary AWS credentials.

### IAM Role

A role has two important conceptual parts:

```text
Trust policy
→ Who may assume the role?

Permissions policy
→ What may the assumed role do?
```

### Future GitHub OIDC design

Planned architecture:

```text
GitHub Actions
     ↓
GitHub OIDC token
     ↓
AWS STS
     ↓
IAM Role
     ↓
Temporary AWS credentials
     ↓
Terraform
     ↓
AWS
```

The goal is to avoid storing long-lived AWS access keys in GitHub Actions.

## GitHub documentation state

IAM troubleshooting documentation was already committed:

```text
commit: ac1cfed
message: Document IAM authentication troubleshooting
```

GitHub identity:

```text
mess-yimam-sec
```

Repository remote was updated and verified.

Working tree was clean.

This summary should be committed under:

```text
docs/identity-and-authentication-session-summary.md
```

## Current checkpoint

```text
AWS CLI 2.36.21                    ✓
Region: us-east-1                  ✓

IAM user: mess-bg-lab              ✓
IAM group: CloudLab-PowerUser      ✓
PowerUserAccess                    ✓
SignInLocalDevelopmentAccess       ✓

Passkey MFA                        ✓
Virtual TOTP MFA                   ✓
TOTP verification                  ✓

aws login                          ❌
IAM GetUser console access         ❌ expected under least privilege
Long-lived bootstrap profile       ✓
Temporary STS credentials          ✓
Temporary expiration behavior      ✓

GitHub: mess-yimam-sec             ✓
Repository: enterprise-security-lab ✓

Next learning module:
IAM Roles → STS → OAuth → OIDC → GitHub Actions → AWS
```

## Next session

Do not restart the IAM setup.

Resume by:

1. Generate a fresh temporary session from `mess-bg-lab-longterm`.
2. Run `sts get-caller-identity` with the fresh `mess-bg-lab-bootstrap` profile.
3. Re-test `ec2:DescribeVpcs` while the token is definitely fresh.
4. Resolve/document the remaining EC2 authorization behavior if it persists.
5. Keep the `iam:GetUser` console error documented as a least-privilege behavior unless we intentionally choose a narrowly scoped IAM read policy.
6. Begin the practical IAM Roles + STS module.
7. Then progress to OAuth/OIDC and GitHub Actions → AWS with temporary credentials.

## Security rules

Never commit:

- Access keys
- Secret access keys
- MFA seed/secret
- QR codes
- Session tokens
- Passwords
- Downloaded AWS credential CSV files
- `.aws/credentials`

Keep credential material outside Git and continue using:

> Build → Automate → Secure → Validate → Document
