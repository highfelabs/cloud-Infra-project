Project Explanation — AWS SaaS Cloud Infrastructure

What This Project Is
This project builds a production-grade AWS infrastructure from scratch using Terraform. The goal was to design and implement a cloud architecture that could realistically host a SaaS application — not a toy demo, but something engineered with the same decisions a cloud engineer would make in a real job.
Every component was built deliberately, with explicit reasoning behind each choice. This document explains those decisions and the tradeoffs involved.

Architecture Overview
The infrastructure is a classic three-tier architecture — load balancer, application, database — deployed inside a custom VPC across two availability zones. Each tier lives in its own subnet layer with its own security boundary. Nothing crosses tiers without explicit permission.
Internet → ALB (public subnet) → EC2 ASG (private subnet) → RDS MySQL (DB subnet)
                                         ↕                         ↕
                                   S3 (storage)          Secrets Manager (creds)

Architecture Decisions
Decision 1 — Custom VPC over default VPC
Choice: Build a custom VPC with manually defined CIDR blocks and subnet tiers.
Why: The default VPC puts everything in public subnets with public IPs. That is fine for experimentation but unacceptable for any real workload. A custom VPC gives full control over routing, subnet isolation, and what is and isn't reachable from the internet. It also mirrors what every real production AWS environment looks like.
Tradeoff: More complexity upfront. Subnets, route tables, IGW, NAT Gateways, and associations all have to be defined explicitly. Worth it because the security and isolation benefits are fundamental — you can't retrofit proper network segmentation later.

Decision 2 — Three subnet tiers
Choice: Public subnets for the ALB, private app subnets for EC2, private DB subnets for RDS — each with its own route table.
Why: Each tier has a different exposure requirement. The ALB needs to face the internet. EC2 instances need outbound internet for updates but should never be directly reachable inbound. RDS should have no internet access at all, inbound or outbound. Separate subnet tiers with separate route tables enforces this cleanly.
Tradeoff: Three times the subnets to manage, multiplied by the number of AZs. For two AZs that's six subnets and multiple route tables. The operational overhead is low since Terraform manages it, and the security benefit is high.

Decision 3 — Application Load Balancer over direct EC2 access
Choice: All traffic enters through an ALB. EC2 instances are never directly accessible.
Why: The ALB provides SSL termination, health checks, and traffic distribution across instances. Without it, adding or removing instances requires DNS changes and there is no automatic failover. The ALB also provides a single entry point that can have WAF attached later.
Tradeoff: Cost. An ALB runs approximately $16-25 per month at baseline before data processing charges. For a dev environment this is significant. The alternative — a Network Load Balancer — is cheaper but lacks HTTP-level features like path-based routing, host headers, and sticky sessions.

Decision 4 — Auto Scaling Group with Launch Template
Choice: EC2 instances managed by an ASG using a Launch Template, not manually provisioned instances.
Why: Manual instances are a single point of failure and cannot scale. An ASG automatically replaces unhealthy instances, scales based on load, and enables zero-downtime rolling deployments when the Launch Template changes. The Launch Template captures the instance configuration as code — AMI, instance type, security groups, IAM profile, user data — so every instance is identical.
Tradeoff: More moving parts. Debugging requires understanding ASG lifecycle hooks, instance refresh behaviour, and health check grace periods. The ignore_changes = [desired_capacity] lifecycle rule also means Terraform stops managing desired capacity after the first apply, which is correct behaviour but counterintuitive.

Decision 5 — SSM Session Manager over SSH and bastion host
Choice: No SSH port open, no key pairs, no bastion host. All instance access via AWS SSM Session Manager.
Why: A bastion host is another instance to patch, secure, and pay for. An open port 22 is an attack surface. Key pairs can be lost, copied, or compromised. SSM Session Manager requires none of these — access is controlled entirely by IAM, every session is logged to CloudTrail, and nothing is exposed to the internet. It is strictly better than SSH in every dimension except familiarity.
Tradeoff: Requires the instance to have outbound internet access to reach SSM endpoints, or VPC endpoints if completely isolated. Also requires the AWS CLI and sufficient IAM permissions on the operator's local machine. Teams used to SSH may find the workflow unfamiliar initially.

Decision 6 — RDS MySQL over self-managed database on EC2
Choice: AWS RDS managed MySQL instead of running MySQL on an EC2 instance.
Why: Running a database on EC2 means manually handling backups, patching, failover, replication, and monitoring. RDS handles all of these. Multi-AZ gives synchronous replication and automatic failover. Automated backups run daily with a 7-day retention window. Enhanced monitoring gives OS-level metrics. The operational overhead reduction is enormous.
Tradeoff: Cost and control. RDS is significantly more expensive than an EC2 instance running MySQL — a db.t3.medium Multi-AZ instance runs approximately $70-100 per month. You also cannot SSH into the underlying instance or modify engine parameters outside of parameter groups. For a dev environment, multi_az = false and a smaller instance class reduces cost significantly.

Decision 7 — Secrets Manager over environment variables
Choice: RDS credentials stored in AWS Secrets Manager, fetched at boot time by EC2 instances.
Why: Environment variables baked into user data or launch templates appear in the AWS console, in Terraform state, and in any tooling that reads instance configuration. Secrets Manager encrypts credentials at rest, controls access via IAM, enables rotation, and provides an audit trail of every access. The only thing an instance needs is permission to call GetSecretValue on a specific secret ARN.
Tradeoff: Additional complexity in the bootstrap process. The instance must successfully call Secrets Manager before the application can start. Network issues, IAM misconfiguration, or a secret with no current version will cause a boot failure. This is why the null_resource waiter was added — to guarantee the secret is populated before instances launch.

Decision 8 — S3 for static assets and ALB logs
Choice: Two separate S3 buckets — one for application assets, one for ALB access logs.
Why: Separation of concerns. ALB logs require a specific bucket policy granting the AWS ELB service account write access. Mixing logs with application data creates permission complexity and makes lifecycle management harder. Separate buckets means separate encryption, separate lifecycle rules, and separate access policies.
Tradeoff: Slightly more Terraform to manage. Two buckets, two public access blocks, two encryption configurations, two lifecycle rules. The operational benefit of clean separation outweighs the extra configuration lines.

Decision 9 — Terraform modules over a single flat file
Choice: Each concern — VPC, security groups, launch template, ALB, ASG, RDS, S3 — is its own reusable module.
Why: A single main.tf with 800 lines is impossible to maintain and impossible to reuse. Modules enforce separation of concerns — each module owns its resources and communicates through outputs and inputs only. Adding a second environment (staging, prod) means calling the same modules with different variable values. Changing the RDS configuration does not require touching the VPC code.
Tradeoff: More files, more indirection, more outputs to wire together. Debugging a variable not found error requires tracing through multiple files. The upfront investment in structure pays off at scale and with team members.

Decision 10 — Remote state in S3 with DynamoDB locking
Choice: Terraform state stored in an encrypted S3 bucket with DynamoDB locking, not on a local machine.
Why: Local state is lost if the machine dies. It cannot be shared with a team. There is no locking — two people running terraform apply simultaneously can corrupt state. S3 remote state solves all three problems. DynamoDB locking prevents concurrent writes. S3 versioning means every previous state is recoverable. Encryption means sensitive values in state are protected at rest.
Tradeoff: The S3 bucket and DynamoDB table must exist before Terraform can initialise, creating a chicken-and-egg problem. This is solved with a bootstrap script that creates them using the AWS CLI before the first terraform init. It is a one-time setup cost.

Key Tradeoffs Summary
DecisionWhat was gainedWhat was tradedCustom VPCFull network control, proper isolationComplexity, more resources to manageThree subnet tiersSecurity isolation per tier6+ subnets, multiple route tablesALBHealth checks, SSL termination, scaling~$20/month baseline costASG + Launch TemplateSelf-healing, auto-scaling, zero-downtime deploysMore complex debuggingSSM over SSHNo exposed ports, IAM-controlled, audit logsUnfamiliar to SSH-first engineersRDS managedAutomated backups, failover, patchingHigher cost, less controlSecrets ManagerNo hardcoded credentials, rotation supportBoot dependency, extra IAM configSeparate S3 bucketsClean separation, independent lifecycle rulesMore Terraform configurationTerraform modulesReusable, maintainable, environment parityMore files, more wiringRemote stateTeam-safe, recoverable, lockableBootstrap script required

What I Would Do Differently at Scale
HTTPS and a real domain — The HTTP listener currently forwards rather than redirecting to HTTPS. In production this would be the first thing to add — an ACM certificate, an HTTPS listener, and an HTTP to HTTPS 301 redirect.
WAF on the ALB — AWS WAF with managed rule groups protects against SQL injection, XSS, and common exploit patterns with minimal configuration. It should sit in front of every public-facing ALB.
VPC Flow Logs — Network-level visibility into what traffic is flowing where. Essential for security forensics and debugging unexpected connectivity issues.
CloudTrail — Every API call in the account logged to S3. Without it there is no audit trail of who changed what and when.
Parameter Store for non-secret config — Secrets Manager is for secrets. Non-sensitive configuration — feature flags, environment names, service URLs — belongs in SSM Parameter Store, which is cheaper and simpler for values that don't need encryption.
Separate AWS accounts per environment — In a real organisation, dev and prod would be in separate AWS accounts with separate state buckets and separate IAM roles. Account-level isolation is stronger than environment separation within a single account.

Built as part of a AWS cloud infrastructure project — highfelabs/cloud-Infra-project