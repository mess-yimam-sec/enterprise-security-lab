# IAM Authentication Troubleshooting
## Purpose
This document captures the AWS IAM and CLI authentication problems I worked through while establishing the identity foundation for the
Enterprise Security Lab.
The goal was not just to get the AWS CLI working. I wanted to understand why each failure happened and how authentication, authorization, MFA,
IAM policies, group membership, and temporary credentials fit together.

These lessons became part of the security foundation for the rest of the
project.
------------------------------------------------------------------------
## Environment
The troubleshooting started with:
-   AWS CLI `2.36.21`
-   Windows 11
-   AWS Region `us-east-1`
-   Lab IAM user `mess-bg-lab`

At this stage, the AWS CLI did not yet have a working credential path.
Running:
powershell
> aws sts get-caller-identity
returned:
NoCredentials: Unable to locate credentials

Rather than immediately creating permanent access keys, I used the authentication problems as an opportunity to understand the available
credential options and build a safer approach.
------------------------------------------------------------------------
## Authentication vs. Authorization
One of the most important lessons from this work was learning to separate authentication from authorization.

Authentication answers: **Who are you?**
Authorization answers: **What are you allowed to do?**

This distinction became important several times during the lab. I could successfully sign in as an IAM user but still receive `AccessDenied` for certain IAM or EC2 operations.

That did not necessarily mean authentication was broken. It often meant the authenticated identity did not have permission to perform that
particular action.
------------------------------------------------------------------------
## AWS CLI Browser Authentication
I initially tested the AWS CLI browser sign-in flow.

The browser authentication reached AWS successfully but eventually returned to a localhost callback similar to:

127.0.0.1:<port>/oauth/callback
The browser then reported that the connection was refused.
I verified the AWS CLI version and then tested:
powershell
>aws login --remote
This allowed me to continue investigating the authentication path without depending on the local browser callback.
------------------------------------------------------------------------
## MFA Authentication
The remote authentication flow reached the IAM-user sign-in process, but MFA authentication returned an invalid-request error.

At the same time, the IAM user could successfully sign in to the AWS Management Console using the same account credentials and an existing
passkey. That helped narrow the problem down. The IAM user itself was valid, and the password was not the issue. The difference was in the MFA mechanism being used by the authentication workflow.
------------------------------------------------------------------------
## Passkey and TOTP
The IAM user already had a passkey configured for AWS console authentication.

I kept that passkey in place and added an authenticator-app TOTP method rather than removing an authentication method that was already working.
The resulting approach was:
mess-bg-lab
│
├── Passkey
│   └── Console authentication
│
└── TOTP authenticator
    └── MFA workflow requiring TOTP

The TOTP authenticator was tested successfully through AWS.
This was a useful reminder that an authentication method that works for one AWS access path should not automatically be assumed to work the same way for every CLI or API credential workflow.
------------------------------------------------------------------------
## IAM `ListUsers` Access Denied
While signed in as `mess-bg-lab`, the IAM Users page returned an authorization error for:
iam:ListUsers

At first, this made it look as though the lab user might not exist or that something was wrong with the login.

The actual issue was simpler: the identity was authenticated, but it did not have permission to list IAM users.
I deliberately did not solve this by attaching broad administrative permissions just to make the console page work. That would have hidden
the real authorization issue and weakened the least-privilege approach I wanted for the lab.
------------------------------------------------------------------------
## IAM Group Permissions
The lab identity used IAM group membership to receive permissions.
One of the policies involved in the authentication setup was:

SignInLocalDevelopmentAccess

A useful lesson here was that permissions inherited through a group do not need to be duplicated directly on the IAM user.
Later troubleshooting also showed how important it is to verify effective group membership rather than assuming a policy is active
simply because the group itself exists.
------------------------------------------------------------------------
## EC2 Authorization Failure
A later problem occurred when the lab identity attempted to call EC2
APIs.
The identity received an `AccessDenied` response for operations such as:

ec2:DescribeVpcs
The final cause was not a broken AWS CLI login.

`mess-bg-lab` was not an effective member of the expected `CloudLab-PowerUser` group.

After correcting the group membership and refreshing the temporary credentials, the EC2 request succeeded.
This connected several concepts:
Authentication
      |
      v
IAM identity
      |
      v
Group membership
      |
      v
Effective permissions
      |
      v
Temporary credentials
      |
      v
AWS API authorization

A valid login alone was not enough. The permissions associated with the identity also had to be correct, and refreshed temporary credentials had to reflect the corrected authorization state.
------------------------------------------------------------------------
## Expected IAM Denials
After the group-membership issue was corrected, some IAM administrative
operations could still be denied.
For example:
iam:GetUser
A denial like this was not necessarily a problem.
The lab identity was intended for normal lab operations rather than unrestricted IAM administration.
This reinforced an important principle for the project:

> A denied action can be evidence that least privilege is working as > intended.

The goal is not to eliminate every `AccessDenied` message. The goal is to make sure the identity has the permissions it actually needs and that denied operations are intentional.
------------------------------------------------------------------------
## Temporary Credential Strategy
I intentionally avoided treating long-lived AWS access keys as the default solution to the authentication problems.
The project moved toward temporary credentials and role-based access wherever practical.
The working pattern became:

Lab identity
      |
      v
Authentication
      |
      v
Temporary AWS credentials
      |
      v
AWS STS identity verification
      |
      v
Authorized AWS API access

I used:
 powershell
>aws sts get-caller-identity
as an important verification step.

Instead of assuming credentials were correct because a login appeared successful, I could verify which AWS identity was actually being used before performing infrastructure operations.
This same preference for short-lived credentials later carried into the GitHub Actions design, where GitHub OIDC and AWS STS are used instead of storing permanent AWS access keys in GitHub.
------------------------------------------------------------------------
## Final Working State
The original authentication and authorization issues were resolved.The final troubleshooting sequence showed that several different problems had been involved rather than one single IAM failure:
Missing CLI credentials
        |
        v
Browser authentication troubleshooting
        |
        v
MFA investigation
        |
        v
Passkey / TOTP distinction
        |
        v
IAM authorization troubleshooting
        |
        v
Group membership correction
        |
        v
Temporary credential refresh
        |
        v
AWS API access verified
The `ec2:DescribeVpcs` failure was ultimately resolved by correcting the effective `CloudLab-PowerUser` group membership and refreshing the temporary credentials.

The remaining IAM administrative denials were treated separately and evaluated based on whether the lab identity actually required those permissions. This was more useful than simply adding broader permissions until every
command succeeded.
------------------------------------------------------------------------
## Credential Security Decisions
Several security decisions came out of this troubleshooting work:
-   Do not use the AWS root user for Terraform, AWS CLI operations,
    Python/boto3 automation, or routine lab activity.
-   Prefer temporary credentials where practical.
-   Do not store passwords, MFA secrets, QR codes, session tokens, or
    AWS credentials in Git.
-   Verify the active AWS identity before performing infrastructure
    operations.
-   Do not add administrative permissions merely to remove an expected
    `AccessDenied` message.
-   Use IAM roles and scoped permissions as the lab grows.

These decisions became part of the broader security model used throughout the Enterprise Security Lab.
------------------------------------------------------------------------
## Lessons Learned
### Authentication and authorization are separate problems
A successful login proves an identity. It does not mean that identity can perform every AWS action.

### Troubleshoot the denied action before expanding permissions
An `AccessDenied` response should be investigated in context. Sometimes a permission is genuinely missing; other times the denial is exactly what the security design should produce.

### Effective permissions matter
Having a policy attached to a group is useful only if the intended identity actually receives that group's permissions.

### Temporary credentials need to reflect permission changes
After changing IAM permissions or group membership, existing temporary credentials may not represent the new authorization state. Refreshing the session can be part of validating the change.

### MFA methods serve different authentication workflows
A passkey working for console authentication does not mean every CLI or API workflow will use it in the same way. Testing the actual access path matters.

### Root access should remain administrative
Routine lab activity should use dedicated identities and roles rather than the AWS root user.

### Troubleshooting is part of the project
The failures were useful because they forced me to understand the security model instead of simply following a successful setup path.

The process involved reading AWS errors, identifying whether a failure was authentication or authorization, checking IAM policy scope and group membership, refreshing credentials, and validating the final identity.

That experience became part of the foundation for the later Terraform, GitHub OIDC, and CI/CD work.
------------------------------------------------------------------------
## Related Documentation
-   [Enterprise Security Lab](../README.md)
-   [Documentation Index](./README.md)
-   [GitHub OIDC → AWS Federation](./github-oidc-aws-federation.md)
-   [Terraform CI/CD Validation](./terraform-cicd-validation.md)
-   [Milestone 2 --- Secure Terraform
    CI/CD](./milestone-2-secure-terraform-cicd.md)
-   [Milestone 3 --- Controlled Terraform
    Deployment](./milestone-3-controlled-terraform-deployment.md)
