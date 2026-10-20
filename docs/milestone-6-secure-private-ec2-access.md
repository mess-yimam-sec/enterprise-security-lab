# Milestone 6 — Secure Private EC2 Access with AWS Systems Manager

## Overview

In this milestone, I implemented secure administrative access to a private AWS EC2 instance using AWS Systems Manager Session Manager, without exposing the instance to the public internet or opening inbound SSH ports.

## What I implemented

- Configured an EC2 IAM role and instance profile with the `AmazonSSMManagedInstanceCore` managed policy.
- Deployed private VPC interface endpoints for Systems Manager (`ssm`) and Session Manager messaging (`ssmmessages`) using Terraform.
- Configured security groups to allow HTTPS communication between the private EC2 instance and the VPC endpoints.
- Deployed infrastructure through a protected GitHub Actions workflow using AWS OIDC authentication.
- Verified the SSM agent was Online, connected through Session Manager, and confirmed the session appeared in Session history.

## Challenges and lessons learned

The EC2 instance initially did not appear under Systems Manager managed nodes, even though its IAM permissions, VPC endpoints, DNS settings, security groups, and network ACLs were configured correctly. After checking these components, I rebooted the instance and the SSM agent registered successfully.

This milestone strengthened my understanding of IAM instance profiles, private AWS networking, secure remote administration, and systematic connectivity troubleshooting.

## Result

Successfully accessed the private EC2 instance through Session Manager without a public IP address, NAT gateway, or inbound SSH.

**Future improvements:** Enable centralized session logging in CloudWatch Logs or S3, and evaluate additional KMS encryption and least-privilege session access controls.
