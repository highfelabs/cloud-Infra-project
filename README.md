# cloud-Infra-project

"I've designed a highly available, secure 3-tier AWS infrastructure using Terraform, deployed across multiple availability zones inside a custom VPC.
Entry point — Application Load Balancer
Users access the application through an internet-facing Application Load Balancer sitting in public subnets. The ALB security group allows HTTP and HTTPS inbound from the internet only. HTTP traffic on port 80 forwards directly to the target group, with HTTPS planned as the next enhancement via ACM. The ALB performs health checks on every instance and only routes traffic to healthy targets.
Application tier — EC2 Auto Scaling Group
Behind the ALB sits a fleet of EC2 instances in private app subnets, managed by an Auto Scaling Group using a Launch Template. The ASG automatically scales out when CPU exceeds 70% and scales in when it drops below 30%, with CloudWatch alarms driving both policies. Instances use a rolling refresh strategy so deployments are zero-downtime.
The instances are never publicly accessible — their security group only accepts traffic from the ALB security group on ports 80 and 443, and ICMP is scoped to the VPC CIDR only. There is no SSH access and no key pairs — all instance access is handled through AWS SSM Session Manager, eliminating the need for a bastion host entirely.
Each instance boots using a hardened Launch Template — IMDSv2 is enforced to block SSRF-based credential theft, root volumes are encrypted gp3, and detailed CloudWatch monitoring is enabled.
For outbound internet access — package updates, AWS API calls — private subnets route through NAT Gateways in the public subnets. Instances never have direct inbound exposure from the internet.
Database tier — RDS MySQL
The database layer sits in isolated DB subnets with no internet route at all. RDS runs MySQL in a Multi-AZ configuration with a synchronous standby replica in a second AZ, providing automatic failover with no data loss. The RDS security group only accepts connections on port 3306 from the application server security group — nothing else can reach the database.
RDS credentials are never hardcoded. Terraform auto-generates a 24-character password using the random provider and stores the full connection string — host, port, username, password, and database name — in AWS Secrets Manager. Instances fetch credentials at boot time using their IAM role, so no secrets ever touch the codebase or environment variables.
Storage — S3
Two S3 buckets are provisioned — one for application assets and uploads, one dedicated to ALB access logs. Both have public access fully blocked, AES256 encryption at rest, and versioning enabled on the app bucket with lifecycle rules to transition old versions to Standard-IA after 30 days. The EC2 IAM role has least-privilege access scoped specifically to the app bucket.
IAM and access control
The EC2 instance role has exactly three permissions — SSM Session Manager access, read/write on the app S3 bucket, and GetSecretValue on the specific RDS secret. Nothing more. There are no wildcard permissions and no hardcoded credentials anywhere in the infrastructure.
Infrastructure as Code — Terraform
The entire stack is built in Terraform with a modular structure — VPC, security groups, launch template, ALB, ASG, RDS, and S3 are each independent reusable modules. Terraform state is stored remotely in an encrypted S3 bucket with DynamoDB state locking to prevent concurrent applies. This means the full infrastructure can be torn down and rebuilt from scratch with a single terraform apply.

Overall, this design enforces layered security, high availability, and controlled access between tiers.”



# AWS SaaS Cloud Infrastructure — Terraform

A production-grade, modular AWS infrastructure built with Terraform over 13 days.
Deploys a fully automated SaaS stack with VPC, EC2 Auto Scaling, RDS MySQL, S3, ALB, IAM, and remote state.

[![Terraform](https://img.shields.io/badge/Terraform->=1.3-7B42BC?logo=terraform)](https://terraform.io)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazonaws)](https://aws.amazon.com)

---




## Architecture

```
                         ┌──────────────────────────────────────────────────┐
                         │                    AWS VPC                        │
                         │              CIDR: 30.0.0.0/16                   │
  Users (Internet)       │                                                   │
        │                │  ┌─────────────────────────────────────────────┐ │
        ▼                │  │              Public Subnets                  │ │
  ┌──────────────┐       │  │         us-east-1a  │  us-east-1b           │ │
  │   Internet   │       │  │  ┌──────────────────────────────────────┐   │ │
  │   Gateway    │──────▶│  │  │     Application Load Balancer        │   │ │
  └──────────────┘       │  │  │         (HTTP :80 → forward)         │   │ │
                         │  │  └──────────────────────────────────────┘   │ │
                         │  │  ┌────────────┐    ┌────────────┐           │ │
                         │  │  │  NAT GW    │    │  NAT GW    │           │ │
                         │  │  │  AZ-1a     │    │  AZ-1b     │           │ │
                         │  └──┴────────────┴────┴────────────┴───────────┘ │
                         │                    │                              │
                         │  ┌─────────────────▼───────────────────────────┐ │
                         │  │            Private App Subnets               │ │
                         │  │         us-east-1a  │  us-east-1b           │ │
                         │  │  ┌──────────────┐  ┌──────────────┐         │ │
                         │  │  │  EC2 (ASG)   │  │  EC2 (ASG)   │         │ │
                         │  │  │  nginx app   │  │  nginx app   │         │ │
                         │  │  └──────────────┘  └──────────────┘         │ │
                         │  │       Auto Scaling Group (min:1 max:3)       │ │
                         │  └─────────────────────────────────────────────┘ │
                         │                    │                              │
                         │  ┌─────────────────▼───────────────────────────┐ │
                         │  │            Private DB Subnets                │ │
                         │  │         us-east-1a  │  us-east-1b           │ │
                         │  │  ┌──────────────┐  ┌──────────────┐         │ │
                         │  │  │  RDS MySQL   │  │  RDS Standby │         │ │
                         │  │  │  (Primary)   │  │  (Multi-AZ)  │         │ │
                         │  │  └──────────────┘  └──────────────┘         │ │
                         │  └─────────────────────────────────────────────┘ │
                         └──────────────────────────────────────────────────┘

              ┌─────────────────────────────────────────────────────────┐
              │                    AWS Services                          │
              │  S3              — App bucket + ALB access logs         │
              │  Secrets Manager — RDS credentials (auto-generated)     │
              │  CloudWatch      — ASG CPU + RDS alarms                 │
              │  SSM             — Instance access (no SSH/bastion)     │
              │  Remote State    — S3 bucket + DynamoDB locking         │
              └─────────────────────────────────────────────────────────┘
```

---

## Traffic Flow

```
User
 └─▶ Internet Gateway
      └─▶ Application Load Balancer (public subnet)
           └─▶ EC2 App Servers via Target Group (private app subnet)
                ├─▶ Secrets Manager — fetch RDS credentials on boot
                ├─▶ S3 — read/write app assets
                └─▶ RDS MySQL (private DB subnet, port 3306)
```

---

## Modules

| Module | What it builds |
|---|---|
| `vpc` | VPC, 3 subnet tiers across 2 AZs, IGW, NAT Gateways, route tables |
| `sg` | ALB SG (HTTP/HTTPS from internet), App SG (from ALB only), RDS SG (from App SG only) |
| `launch-template` | EC2 blueprint — IMDSv2, encrypted gp3 EBS, SSM, no public IP |
| `alb` | Internet-facing ALB, Target Group with health checks, HTTP listener |
| `asg` | Auto Scaling Group, rolling refresh, CloudWatch scale out/in alarms |
| `rds` | MySQL RDS, auto-generated password, Secrets Manager, enhanced monitoring |
| `s3` | Versioned app bucket, ALB logs bucket, EC2 IAM access policy |

---

## Module Dependency Flow

```
vpc
 ├── security-groups   (needs vpc_id, vpc_cidr)
 │    ├── launch-template  (needs app_sg_id)
 │    ├── alb              (needs alb_sg_id)
 │    ├── rds              (needs app_sg_id)
 │    └── db-server        (needs db_server_sg_id)
 ├── alb → asg            (needs target_group_arn + launch_template_id)
 └── s3                   (independent, bucket name injected into user_data)
```

---

## Environments

| Setting | Prod | Staging |
|---|---|---|
| NAT Gateways | One per AZ (3) | Single shared |
| RDS Multi-AZ | Yes | No |
| ASG min/max | 2 / 6 | 1 / 3 |
| Instance type | `t3.medium` | `t3.small` |
| ALB deletion protection | Yes | No |
| RDS final snapshot | Yes | No |
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` |

---

## Prerequisites

- Terraform >= 1.3.0
- AWS CLI configured (`aws configure`)
- Sufficient AWS IAM permissions

---

## Deploy

**Step 1 — Bootstrap remote state (run once only)**
```bash
chmod +x scripts/bootstrap-state.sh
./scripts/bootstrap-state.sh us-east-1
```

**Step 2 — Deploy**
```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

**Step 3 — Open dashboard**
```bash
terraform output alb_dns_name
```

---

## Useful Commands

```bash
# View all outputs
terraform output

# Get RDS password
terraform output -raw rds_password

# List running instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[InstanceId,Tags[?Key=='Name'].Value|[0]]" \
  --output table --region us-east-1

# SSM into an instance (no SSH needed)
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx --region us-east-1

# Check app logs inside instance
journalctl -u saas-app -f
cat /var/log/user-data.log

# Trigger rolling instance refresh
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name saas-infra-asg \
  --region us-east-1
```
---

## Security Highlights

| Control | Implementation |
|---|---|
| No public EC2 instances | App and DB servers in private subnets only |
| No hardcoded credentials | RDS password auto-generated, stored in Secrets Manager |
| IMDSv2 enforced | Blocks SSRF-based credential theft on all instances |
| Encrypted storage | All EBS volumes and RDS storage encrypted at rest |
| S3 public access blocked | All public access blocked on every bucket |
| Least-privilege IAM | EC2 role scoped to SSM, specific S3 bucket, and RDS secret only |
| Server management | AWS SSM Session Manager — no SSH, no bastion, no port 22 |

---



## Project Structure


cloud-Infra-project/
├── modules/
│   ├── vpc/                  # main.tf · variables.tf · outputs.tf
│   ├── sg/                   # main.tf · variables.tf · outputs.tf
│   ├── launch-template/      # main.tf · variables.tf · outputs.tf
│   ├── alb/                  # main.tf · variables.tf · outputs.tf
│   ├── asg/                  # main.tf · variables.tf · outputs.tf
│   ├── rds/                  # main.tf · variables.tf · outputs.tf
│   └── s3/                   # main.tf · variables.tf · outputs.tf
│
├── environments/
│   └── dev/
│       ├── main.tf           # Wires all modules together
│       ├── variables.tf      # All input variables
│       ├── outputs.tf        # ALB URL, RDS endpoint, S3 bucket etc
│       ├── terraform.tfvars  # Dev environment values
│       └── user_data.sh      # EC2 bootstrap — installs nginx, fetches RDS creds
│
├── scripts/
│   └── bootstrap-state.sh   # Run once — creates S3 + DynamoDB for remote state
│
└── README.md
```




## Security Highlights

| Control | How |
|---|---|
| No public EC2 | App servers in private subnets — unreachable from internet |
| No SSH open | Port 22 removed — SSM Session Manager only |
| No hardcoded secrets | RDS password auto-generated, stored in Secrets Manager |
| IMDSv2 enforced | Blocks SSRF credential theft on all instances |
| Encrypted at rest | EBS volumes + RDS storage encrypted |
| S3 fully private | Public access blocked on all buckets |
| Least-privilege IAM | EC2 role scoped to SSM + specific S3 bucket + RDS secret only |
| State file encrypted | Remote state in S3 with server-side encryption |
| State locking | DynamoDB prevents concurrent `terraform apply` |


## Auto Scaling

| Trigger | Threshold | Action |
|---|---|---|
| CPU high | > 70% for 2 minutes | +1 instance |
| CPU low | < 30% for 2 minutes | -1 instance |
| Minimum | Always | 1 instance |
| Maximum | Hard cap | 3 instances |

Instance refresh uses a rolling strategy — 50% minimum healthy, so the app stays up during deploys.

---

## RDS Alarms

| Alarm | Threshold |
|---|---|
| CPU utilisation | > 80% |
| Free storage | < 5 GB |
| Connection count | > 100 |

---

## Remote State

```
saas-infra-tfstate-704225640883/
└── dev/
    └── terraform.tfstate     ← encrypted, versioned, locked
```

DynamoDB table `saas-infra-tf-locks` prevents two engineers running `terraform apply` at the same time.

---
## Author

**highfelabs** — 30-day cloud infrastructure project
