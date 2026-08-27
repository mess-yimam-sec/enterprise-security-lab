# Terraform CI/CD Validation

This milestone validates the integration between GitHub Actions, AWS OIDC, Terraform, and remote Terraform state.

The current workflow:

1. GitHub Actions authenticates to AWS using OIDC.
2. AWS IAM validates the trusted GitHub identity.
3. STS provides temporary AWS credentials.
4. Terraform initializes against the S3 remote state backend.
5. Terraform validates the configuration.
6. Terraform plans changes against the existing AWS infrastructure.

The objective is to use short-lived AWS credentials and least-privilege permissions while keeping Terraform infrastructure changes reviewable through GitHub pull requests.

## Current validation status

- GitHub OIDC authentication: validated
- S3 remote state: validated
- Terraform initialization: validated
- Terraform formatting: validated
- Terraform validation: validated
- EC2 read permissions: being validated through Terraform plan