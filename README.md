# cloud-Infra-project





“I’ve designed a highly available, secure 3-tier architecture inside a VPC spread across multiple AZs.

At the entry point, users access the application through an Application Load Balancer in the public subnets. The ALB only allows HTTP and HTTPS from the internet and forwards traffic to a target group.

Behind that, I have application servers running in private subnets, managed by an Auto Scaling Group using a launch template. These instances are not publicly accessible—their security group only allows traffic from the ALB and SSH access from a bastion host.

For outbound internet access like updates, the private subnets route traffic through a NAT Gateway in the public subnet, so instances never have direct inbound exposure.

The database layer sits in isolated DB subnets with no internet route at all. Its security group only allows connections from the application layer, ensuring strict access control.

For administration, I use a bastion host in the public subnet, which only allows SSH from my IP. From there, I can securely access private and database instances. A better alternative would be AWS Systems Manager to eliminate SSH entirely.

Overall, this design enforces layered security, high availability, and controlled access between tiers.”



# AWS Cloud Infrastructure — Terraform

A modular, multi-environment AWS SaaS infrastructure built with Terraform.
Covers VPC, EC2 (Auto Scaling), RDS, S3, ALB, and IAM — structured for reuse across prod and staging.

---

## Architecture

```
                        ┌─────────────────────────────────────────┐
                        │                  VPC                     │
  Users (internet)      │                                          │
        │               │  ┌──────────────────────────────────┐   │
        ▼               │  │         Public Subnet            │   │
  ┌──────────┐          │  │  ┌────────────────────────────┐  │   │
  │   ALB    │──────────┼──┼─▶│  Application Load Balancer │  │   │
  └──────────┘          │  │  └────────────────────────────┘  │   │
                        │  │  ┌──────────┐                    │   │
                        │  │  │ NAT GW   │ (outbound only)    │   │
                        │  └──┴──────────┴────────────────────┘   │
                        │                                          │
                        │  ┌──────────────────────────────────┐   │
                        │  │       Private App Subnet          │   │
                        │  │  ┌──────────┐  ┌──────────┐      │   │
                        │  │  │  EC2 AZ1 │  │  EC2 AZ2 │ ASG  │   │
                        │  │  └──────────┘  └──────────┘      │   │
                        │  └──────────────────────────────────┘   │
                        │                                          │
                        │  ┌──────────────────────────────────┐   │
                        │  │       Private DB Subnet           │   │
                        │  │  ┌──────────┐  ┌──────────┐      │   │
                        │  │  │  RDS Pri │  │  RDS Stby│ M-AZ │   │
                        │  │  └──────────┘  └──────────┘      │   │
                        │  └──────────────────────────────────┘   │
                        └─────────────────────────────────────────┘
```

### Traffic Flow

```
User → ALB (public subnet) → EC2 App Servers (private subnet) → RDS (DB subnet)
                                      ↕
                               S3 (app assets)
                          Secrets Manager (DB creds)
```

---

## Modules

| Module | What it builds |
|---|---|
| `vpc` | VPC, public/private/DB subnets, IGW, NAT Gateways, route tables |
| `security-groups` | ALB SG, App Server SG, DB Server SG |
| `launch-template` | EC2 Launch Template with IMDSv2, encrypted EBS, SSM |
| `alb` | Application Load Balancer, Target Group, HTTP→HTTPS listeners |
| `asg` | Auto Scaling Group, CloudWatch scale out/in alarms |
| `rds` | MySQL/Postgres RDS, Multi-AZ, Secrets Manager credentials |
| `s3` | App bucket, ALB logs bucket, IAM access policy |
| `db-server` | Locked-down EC2 in DB subnet for admin access |

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
- An ACM certificate in us-east-1 for HTTPS

---

## Usage

### Deploy production

```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```

### Deploy staging

```bash
cd environments/staging
terraform init
terraform plan
terraform apply
```

### Tear down staging

```bash
cd environments/staging
terraform destroy
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

## Connecting to Instances (SSM)

```bash
# Get instance ID
terraform output db_server_instance_id

# Start a session
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx
```

No key pairs or open port 22 required.

---

## Fetching RDS Credentials

```bash
aws secretsmanager get-secret-value \
  --secret-id myapp-prod/rds/credentials \
  --query SecretString \
  --output text | python3 -m json.tool
```

---

## Project Structure

```
cloud-Infra-project/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security-groups/
│   ├── launch-template/
│   ├── alb/
│   ├── asg/
│   ├── rds/
│   ├── s3/
│   └── db-server/
├── environments/
│   ├── prod/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   └── user_data.sh
│   └── staging/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars
│       └── user_data.sh
└── README.md
```

---

## Author

**highfelabs** — 30-day cloud infrastructure project
