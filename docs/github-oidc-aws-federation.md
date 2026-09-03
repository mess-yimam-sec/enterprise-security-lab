GitHub Actions → AWS OIDC Federation
Purpose
This document captures how I connected GitHub Actions to AWS using OpenID Connect (OIDC) in the Enterprise Security Lab.

The goal was simple: I wanted GitHub Actions to work with AWS without storing long-lived AWS access keys in GitHub.

The final authentication path is:
GitHub Actions
      |
      v
GitHub OIDC token
      |
      v
AWS IAM OIDC provider
      |
      v
IAM role trust policy
      |
      v
AWS STS
      |
      v
Temporary AWS credentials
      |
      v
AWS API
This started as a small federation exercise, but it became the identity foundation for the Terraform CI/CD work that followed.

Security principle: GitHub Actions should receive temporary AWS credentials through federation rather than storing permanent AWS access keys as repository secrets.
Why I Used OIDC
Before setting up GitHub OIDC, I had already worked with IAM users, MFA, AWS STS, and temporary credentials.

That helped me see an important difference between local access and CI/CD access.

For a person working locally, an IAM identity can authenticate and obtain temporary credentials. A GitHub Actions workflow is different. I did not want to create an IAM user just for GitHub or store an access key and secret access key in the repository.

OIDC provides a better model:
GitHub proves the workload identity
            |
            v
AWS evaluates whether it trusts that identity
            |
            v
AWS STS issues temporary credentials
The workflow receives AWS access only when it runs and only through the IAM role that AWS allows it to assume.

Federation in This Lab
The federation relationship is between GitHub and AWS.
GitHub
   |
   | OIDC identity token
   v
AWS
GitHub manages the workload identity. AWS trusts GitHub's OIDC identity provider and evaluates the claims in the token against an IAM role trust policy.
The GitHub workflow does not need its own IAM user in AWS.

OAuth 2.0, OIDC, and AWS STS
These technologies are related, but they do different jobs.

OAuth 2.0
OAuth 2.0 is primarily an authorization framework.

I had already encountered an OAuth-based flow while experimenting with ws login, where the CLI waited for a browser callback similar to:

http://127.0.0.1:<port>/oauth/callback
That earlier troubleshooting helped provide context for the GitHub federation work.

OpenID Connect
OIDC adds an identity layer on top of OAuth 2.0.

For this lab, the important idea is that GitHub can issue a signed token describing the identity of the workflow.

Conceptually:

GitHub:
"I am this repository/workflow identity."

AWS validates that token and then checks whether the IAM role's trust policy accepts the identity described by its claims.

AWS STS
AWS Security Token Service issues temporary AWS credentials.

For GitHub OIDC federation, the important operation is:
sts:AssumeRoleWithWebIdentity

My working mental model became:
OIDC
  = workload identity
IAM trust policy
  = who may assume the role
IAM permissions policy
  = what the role may do
AWS STS
  = temporary AWS credentials

That distinction became important later when I separated Terraform planning and deployment permissions.

Creating the AWS OIDC Provider
The AWS account initially had no GitHub OIDC identity provider.
I added an OpenID Connect provider in IAM using:
Provider URL:
https://token.actions.githubusercontent.com

Audience:
sts.amazonaws.com
The provider tells AWS which external token issuer can be trusted.
Creating the provider alone does not give GitHub access to AWS.

The next question is still:
Which GitHub identity is allowed to assume which IAM role?

That decision belongs in the role's trust policy.
The relationship is:
GitHub OIDC provider
        |
        v
IAM role trust policy
        |
        v
AWS STS
Creating the GitHub OIDC Role
For the initial proof of concept, I created:EnterpriseSecurityLab-GitHubOIDC

The role used the GitHub OIDC provider: token.actions.githubusercontent.com

with the AWS STS audience:
sts.amazonaws.com
The role was intentionally limited rather than being given AdministratorAccess.

For the initial federation test, it had read access to networking information such as:
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

This gave me enough permission to prove that federation worked without giving the workflow unnecessary administrative access.
The role was also tagged for the project:
Project = enterprise-security-lab
Purpose = github-oidc

The tags are organizational metadata. They are not part of the authentication decision.

Initial Trust Configuration
The initial GitHub repository scope was:
Owner: mess-yimam-sec
Repository: enterprise-security-lab
For the first proof of concept, I left the branch restriction open while testing the federation path.
The initial trust policy generated through the AWS setup used a repository subject pattern similar to:

repo:mess-yimam-sec/enterprise-security-lab:*
At the time, that looked reasonable.
It turned out not to match the actual OIDC subject GitHub was sending for this repository.

That mismatch became the main troubleshooting issue in this exercise.

GitHub Actions Workflow
The proof-of-concept workflow was created at:.github/workflows/aws-oidc-test.yml

The important parts looked like this:
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

No AWS access key, secret access key, or session token was stored in the
workflow.
Why id-token: write Matters
This workflow permission is required:
permissions:
  id-token: write
  contents: read
At first, id-token: write can sound as though it is granting AWS
permissions. It is not.

It allows the GitHub workflow to request an OIDC identity token.
The process is:
GitHub workflow
      |
      | request OIDC token
      v
GitHub issues identity token
      |
      v
AWS validates token
      |
      v
AWS evaluates IAM trust policy

The actual AWS permissions still come from the IAM role.
This distinction helped reinforce the difference between identity and authorization.
First OIDC Failure
The first workflow reached the AWS credential configuration step but failed with:

Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity

This error was useful because it narrowed down the problem.
At that point:
GitHub workflow             OK
OIDC token request          OK
AWS OIDC provider           OK
AWS role                    Found
Role assumption             Failed

That pointed me toward the IAM role's trust conditions rather than AWS access keys or general GitHub workflow onfiguration.

Instead of broadening the trust policy until the workflow worked, I wanted to understand exactly which claim AWS was rejecting.

Inspecting the GitHub Identity
I temporarily added diagnostic output to the workflow:
- name: Show GitHub repository information
  run: |
    echo "repository=${{ github.repository }}"
    echo "owner_id=${{ github.repository_owner_id }}"
    echo "repo_id=${{ github.repository_id }}"
    echo "ref=${{ github.ref }}"

The output showed:
repository=mess-yimam-sec/enterprise-security-lab
owner_id=314676558
repo_id=1327860875
ref=refs/heads/main

I did not print the OIDC token itself.
These values gave me the information I needed to understand why the role's subject condition did not match the GitHub identity.

Discovering the Actual OIDC Subject
The repository was using GitHub's immutable subject format.
For the branch-based proof of concept, the subject was:
repo:mess-yimam-sec@314676558/enterprise-security-lab@1327860875:ref:refs/heads/main

That was different from the older-style pattern I had initially trusted:
repo:mess-yimam-sec/enterprise-security-lab:*

The owner ID and repository ID were part of the actual identity.
This explained the AssumeRoleWithWebIdentity failure: AWS was correctly rejecting a token whose subject did not match the role's trust
policy.
Correcting the Trust Policy
I updated the role trust policy so the aud and sub claims matched
the actual GitHub token identity.
The branch-based proof-of-concept trust condition became:
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

The important security checks were:
Audience
sts.amazonaws.com
Subject
specific GitHub owner + repository + branch identity
The audience confirms that the token is intended for AWS STS.
The subject restricts which GitHub identity may assume the role. Successful Federation Test
After correcting the trust policy, the workflow completed successfully.

It performed three important checks:
1. Configure AWS credentials using GitHub OIDC
2. Verify the AWS identity
3. Test VPC read access

The workflow ran:
aws sts get-caller-identity
and the resulting ARN identified an assumed role session in the general form:
arn:aws:sts::ACCOUNT-ID:assumed-role/EnterpriseSecurityLab-GitHubOIDC/...

That was important because it proved the workflow was operating through the IAM role rather than as the mess-bg-lab IAM user.

The workflow then ran:aws ec2 describe-vpcs
successfully.
The full chain was now proven:
GitHub workload identity
        |
        v
OIDC token
        |
        v
AWS validates token
        |
        v
IAM trust policy matches
        |
        v
sts:AssumeRoleWithWebIdentity
        |
        v
Temporary role credentials
        |
        v
Role permissions
        |
        v
EC2/VPC API
        |
        v
SUCCESS

Manual IAM Access vs. GitHub OIDC
Earlier in the lab, I used an IAM-user-based path to obtain temporary credentials:
IAM user
   |
   v
Bootstrap credentials
   |
   v
TOTP
   |
   v
AWS STS
   |
   v
Temporary credentials

That approach still requires a credential source for the user.

GitHub OIDC uses a different model:

GitHub Actions
   |
   v
OIDC token
   |
   v
AWS IAM OIDC provider
   |
   v
IAM role
   |
   v
AWS STS
   |
   v
Temporary credentials

The GitHub workflow does not need a long-lived AWS access key.That was the main security improvement I wanted from this exercise.
What OIDC Does --- and Does Not Do
OIDC establishes the workload identity and allows AWS to evaluate whether that external identity is trusted.
OIDC does not decide what the workflow can do inside AWS.

Those responsibilities remain separate:
OIDC = Who is this external workload?
IAM role trust policy = May this workload assume the role?
IAM role permissions = What may the assumed role do?
AWS STS = Issue temporary credentials

This separation became especially important as the Terraform pipeline became more mature.

Troubleshooting Checklist
When I see:
Not authorized to perform sts:AssumeRoleWithWebIdentity I check the federation chain in this order:
The workflow has id-token: write.
The GitHub OIDC provider exists in AWS.
The provider audience is sts.amazonaws.com.

The workflow references the correct IAM role.
The role trusts the GitHub OIDC provider.
The aud claim matches sts.amazonaws.com.
The sub condition matches GitHub's actual subject.
Repository owner and repository IDs are correct when used in the subject.
The branch, environment, or other subject context matches the workflow.
The role's permissions allow the AWS API operation being tested.

I do not treat AdministratorAccess or an unrestricted subjectcondition as troubleshooting shortcuts. If the trust fails, I want to know which identity condition is wrong.

How This Evolved Into Terraform CI/CD
The OIDC proof of concept became the authentication foundation for the Terraform pipeline.

The project later added:
Terraform validation and planning in GitHub Actions
Remote Terraform state in Amazon S3
S3 versioning and public-access protection
Protected main branch and pull-request workflow
Separate permissions for Terraform Plan and Apply
Dedicated Terraform deployment role
Protected terraform-deploy GitHub environment
Manual approval before deployment
Automated Terraform Apply using temporary AWS credentials
The deployment path now builds on the same identity model:

GitHub Actions
      |
      v
GitHub OIDC
      |
      v
AWS STS
      |
      v
Temporary credentials
      |
      v
Scoped IAM role
      |
      v
Terraform
      |
      v
AWS infrastructure

The original EnterpriseSecurityLab-GitHubOIDC role remains part of the CI/Plan side of the project, while Terraform Apply uses the separate deployment role:
EnterpriseSecurityLab-TerraformDeploy
Environment-Protected Deployment
As the project moved from a branch-based OIDC proof of concept to controlled Terraform deployment, the deployment workflow began using the protected GitHub environment:

terraform-deploy
That changed the OIDC subject used by the deployment role.
The deployment identity was verified as:
repo:mess-yimam-sec@314676558/enterprise-security-lab@1327860875:environment:terraform-deploy

The deployment role trust policy was restricted to that exact subject together with:
aud = sts.amazonaws.com
This is separate from the earlier branch-based proof-of-concept subject used by EnterpriseSecurityLab-GitHubOIDC.
The distinction is intentional:
CI / Plan
   |
   v
EnterpriseSecurityLab-GitHubOIDC

Deployment
   |
   v
Protected GitHub environment
   |
   v
EnterpriseSecurityLab-TerraformDeploy
This gave me a cleaner separation between validating infrastructure changes and actually deploying them.

Security Decisions
The OIDC work established several practices that I carried into the rest
of the lab:
Do not store long-lived AWS credentials in GitHub Actions.
Use AWS STS temporary credentials.
Restrict role trust using the actual OIDC audience and subject
claims.
Keep trust policy and permissions policy responsibilities separate.
Give CI and deployment different permissions when their
responsibilities differ.
Use protected GitHub environments for sensitive deployment paths.
Verify the assumed AWS identity with aws sts get-caller-identity.
Do not print OIDC tokens or credential material during troubleshooting.
Do not weaken trust conditions just to make a failed workflow pass.

Final Result

The original federation exercise successfully demonstrated:

GitHub OIDC provider                    OK
GitHub-specific IAM role                OK
Repository identity verified            OK
OIDC token requested                    OK
AWS trust policy validated              OK
sts:AssumeRoleWithWebIdentity           OK
Temporary AWS credentials issued        OK
AWS identity verified                   OK
VPC read access verified                OK
Long-lived AWS key in GitHub            NOT REQUIRED

More importantly, the exercise became the authentication model for the later Terraform CI/CD pipeline.

What began as a test of GitHub-to-AWS federation now supports a design where infrastructure changes can be validated with one set of permissions and deployed through a separate, protected path with temporary AWS credentials.

Related Documentation
Enterprise Security Lab
Documentation Index
IAM Authentication Troubleshooting
Terraform CI/CD Validation
Milestone 2 --- Secure Terraform CI/CD
Milestone 3 --- Controlled Terraform Deployment
