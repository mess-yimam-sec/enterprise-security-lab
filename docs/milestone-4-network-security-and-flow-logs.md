\# Milestone 4: Private Network Security and VPC Flow Logs



In this milestone, I strengthened the network foundation of my Enterprise Security Lab by adding a private subnet and introducing controls to manage its traffic. I used Terraform to create a dedicated private route table with no internet route, along with a security group and network ACL to define network access.



I also enabled VPC Flow Logs for the private subnet to capture network traffic metadata and send it to Amazon CloudWatch Logs. To keep the lab cost-conscious, I configured a three-day log retention period and avoided deploying a NAT Gateway.



The deployment runs through my existing GitHub Actions and AWS OIDC workflow. During implementation, I resolved IAM permission issues related to CloudWatch Logs and Flow Log tagging while keeping the deployment permissions scoped to the lab resources.



\*\*Verification:\*\* I confirmed that the Flow Log is active, captures all traffic types, and is tracked in Terraform state. I also verified the three-day CloudWatch retention setting and ran a final Terraform plan, which reported no changes.



\*\*Outcome:\*\* The lab now has a private network segment with defined access controls and a foundation for network traffic monitoring. This prepares the environment for future security detection and incident-response exercises.



