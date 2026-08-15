# IAM Authentication Troubleshooting

## Project

**Repository:** `mess-big/enterprise-security-lab`

**Project principle:** Build → Automate → Secure → Validate → Document

## Purpose

This document records the IAM/CLI authentication troubleshooting performed before beginning the networking portion of the Enterprise Security Lab.

The goal was not simply to make the CLI work, but to understand the distinction between:

- Authentication vs. authorization
- Console authentication vs. CLI authentication
- Passkey/WebAuthn MFA vs. TOTP MFA
- Long-lived IAM access keys vs. temporary credentials
- Administrative/root access vs. least-privilege lab access

## Initial state

The AWS CLI was installed and configured for:

- AWS CLI: `2.36.21`
- Operating system: Windows 11
- Region: `us-east-1`

Initial command:

```powershell
aws sts get-caller-identity
```

Result:

```text
NoCredentials: Unable to locate credentials
```

`aws configure list` showed:

```text
access_key: not set
secret_key: not set
region: us-east-1
```

No AWS infrastructure had been created at this stage.

---

## Issue 1 — `aws login` failed through the local browser callback

The initial `aws login` browser flow reached AWS authentication but returned to a localhost callback similar to:

```text
127.0.0.1:<port>/oauth/callback
```

The browser reported that the connection was refused.

### Investigation

The AWS CLI was confirmed to be current:

```text
aws-cli/2.36.21
```

Therefore, CLI version incompatibility was ruled out.

`aws login --remote` was tested to bypass the localhost callback.

---

## Issue 2 — `aws login --remote` failed during MFA

The remote authentication flow successfully reached the IAM-user authentication process:

```text
AWS login
  ↓
IAM user
  ↓
Username/password
  ↓
MFA
  ↓
Authentication failed — Invalid request
```

The IAM user could successfully sign into the normal AWS Management Console using the same account credentials and a saved passkey.

This narrowed the issue to the authentication mechanism used by the CLI sign-in flow rather than a basic IAM-user login failure.

---

## Issue 3 — Passkey vs. CLI MFA

The important discovery was AWS's documented limitation around passkeys/security keys.

Passkeys/security keys can be used for AWS Management Console MFA, but they are not supported as MFA mechanisms for AWS CLI/API authentication in the same way that TOTP is.

Therefore:

```text
AWS Console
  ↓
IAM user + password
  ↓
Passkey
  ↓
SUCCESS
```

while the CLI authentication path could fail when attempting to use the passkey.

### Decision

Do not remove the existing passkey.

Instead, add a TOTP authenticator as a second MFA method.

Target design:

```text
mess-bg-lab
│
├── Passkey
│   └── AWS Console authentication
│
└── TOTP authenticator
    └── CLI-compatible MFA workflow
```

---

## Issue 4 — `iam:ListUsers` Access Denied

While logged in as `mess-bg-lab`, the IAM Users page displayed an access-denied message for:

```text
iam:ListUsers
```

This initially looked like the `mess-bg-lab` user might not exist.

The actual explanation was authorization.

The lab IAM user did not have permission to list all IAM users. The user was therefore able to authenticate but was not authorized to perform the administrative IAM operation required to populate the Users page.

This is an important security lesson:

> Authentication proves who you are. Authorization determines what you are allowed to do.

The correct response was **not** to grant broad administrative permissions merely to make the IAM console page work.

Root access was used only for IAM administration.

---

## IAM group configuration

The lab user `mess-bg-lab` was created and placed in an IAM group.

The group already had:

```text
SignInLocalDevelopmentAccess
```

attached.

This policy supports the AWS CLI browser sign-in workflow. The policy being attached through the group is valid; it did not need to be duplicated directly on the user.

The `iam:ListUsers` denial is separate from this policy because `SignInLocalDevelopmentAccess` is not an IAM administration policy.

---

## MFA remediation

While signed in with administrative/root access, the existing passkey was retained.

A second MFA method was added:

**Authenticator app / TOTP**

The hardware MFA option was not selected.

The TOTP authenticator was then tested through the AWS Management Console.

### Result

**TOTP verification succeeded.**

This confirms that the new authenticator is correctly enrolled and generating valid MFA codes.

Current state:

```text
AWS CLI installed                 ✓
AWS region: us-east-1             ✓
mess-bg-lab IAM user              ✓
IAM group                         ✓
SignInLocalDevelopmentAccess      ✓
Passkey MFA                       ✓
TOTP MFA                          ✓
Console TOTP verification         ✓
CLI credential verification       → Next step
VPC deployment                    → After CLI authentication
```

---

## Credential-security decisions

No long-lived access key was created during this troubleshooting session.

This was intentional.

The project will prefer short-lived credentials where practical and will avoid placing credentials, MFA secrets, QR codes, session tokens, or passwords in Git.

If an IAM access key becomes necessary for the chosen CLI workflow, it will be:

1. Created deliberately
2. Stored securely
3. Used only as required
4. Used to obtain temporary/MFA-backed credentials where applicable
5. Never committed to Git

---

## Lessons learned

### 1. Authentication and authorization are different

A successful IAM login does not imply permission to perform every IAM operation.

### 2. Console MFA and CLI MFA are not interchangeable

A passkey can successfully protect console access while not being usable as the MFA mechanism required by a particular CLI authentication workflow.

### 3. Least privilege matters during troubleshooting

Adding `AdministratorAccess` simply because an IAM page reports `AccessDenied` would hide the underlying authorization model and weaken the lab's security posture.

### 4. Root should be administrative, not operational

Root was used to manage the IAM configuration. The lab's normal AWS operations will use a dedicated IAM identity rather than root.

### 5. Troubleshooting is part of the project

The authentication problems are intentionally documented because they demonstrate real Cloud Security skills:

- Reading AWS errors
- Separating authentication from authorization
- Understanding MFA mechanisms
- Understanding IAM policy scope
- Avoiding unnecessary privilege escalation
- Choosing credential mechanisms deliberately

---

## Next step

Before creating any VPC resources:

1. Establish a secure CLI credential workflow for `mess-bg-lab`
2. Run:

```powershell
aws sts get-caller-identity
```

3. Confirm the returned identity is the intended lab identity
4. Document the final credential method
5. Begin Phase 1 — VPC foundation
final discovery to the IAM troubleshooting document:

The initial EC2 AccessDenied was ultimately traced to mess-bg-lab not being an effective member of CloudLab-PowerUser. Once group membership was corrected and temporary credentials were refreshed, ec2:DescribeVpcs succeeded. The iam:GetUser denial remained expected because PowerUserAccess excludes IAM administration

**Do not use the AWS root user for Terraform, AWS CLI operations, Python/boto3 automation, or routine lab activity.**
