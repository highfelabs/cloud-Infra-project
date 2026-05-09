# cloud-Infra-project





“I’ve designed a highly available, secure 3-tier architecture inside a VPC spread across multiple AZs.

At the entry point, users access the application through an Application Load Balancer in the public subnets. The ALB only allows HTTP and HTTPS from the internet and forwards traffic to a target group.

Behind that, I have application servers running in private subnets, managed by an Auto Scaling Group using a launch template. These instances are not publicly accessible—their security group only allows traffic from the ALB and SSH access from a bastion host.

For outbound internet access like updates, the private subnets route traffic through a NAT Gateway in the public subnet, so instances never have direct inbound exposure.

The database layer sits in isolated DB subnets with no internet route at all. Its security group only allows connections from the application layer, ensuring strict access control.

For administration, I use a bastion host in the public subnet, which only allows SSH from my IP. From there, I can securely access private and database instances. A better alternative would be AWS Systems Manager to eliminate SSH entirely.

Overall, this design enforces layered security, high availability, and controlled access between tiers.”