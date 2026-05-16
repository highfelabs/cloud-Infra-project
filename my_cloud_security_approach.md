My Cloud Security Approach
highfelabs — AWS SaaS Infrastructure Project

Philosophy
Security is not a feature added at the end — it is built into every layer of the infrastructure from the start. My approach follows the principle of least privilege, defence in depth, and zero trust between tiers. Every access decision is explicit, every credential is managed, and every component assumes the others can be compromised.

Network Security
Three-tier subnet isolation
The VPC is divided into three distinct subnet tiers — public, private app, and private DB — each with its own route table. Public subnets only host the load balancer. Application servers live in private subnets with no inbound route from the internet. The database sits in DB subnets with no internet route at all, inbound or outbound.
NAT Gateway — outbound only
Private instances need outbound internet access for package updates and AWS API calls. Rather than giving them public IPs, all outbound traffic routes through NAT Gateways in the public subnets. Instances are never directly reachable from the internet.
Security group chaining
Traffic flows through explicit security group rules at every tier:

ALB SG — accepts HTTP/HTTPS from 0.0.0.0/0 only
App SG — accepts traffic from ALB SG only, no direct internet access
RDS SG — accepts port 3306 from App SG only, nothing else

No tier can communicate with another unless explicitly permitted. There are no wildcard ingress rules between tiers.

Identity and Access
No SSH, no bastion, no key pairs
All EC2 instance access is handled through AWS SSM Session Manager. Port 22 is not open on any security group. There are no EC2 key pairs attached to any instance. This eliminates an entire class of attack vectors — exposed keys, brute force SSH, lateral movement through a bastion host.
Least-privilege IAM
The EC2 instance role has exactly three permissions:

AmazonSSMManagedInstanceCore — SSM access only
S3 read/write scoped to a specific bucket ARN
secretsmanager:GetSecretValue scoped to the specific RDS secret ARN

No wildcards. No * on actions or resources. If an instance is compromised, the blast radius is limited to those three things.
IMDSv2 enforced
All instances require IMDSv2 token-based metadata access. IMDSv1 is disabled. This blocks SSRF-based attacks that attempt to steal IAM credentials through the instance metadata endpoint — a common attack vector in cloud environments.

Secrets Management
No hardcoded credentials — anywhere
There are no passwords, connection strings, or API keys in code, environment variables, user data scripts, or Terraform files. Every secret is managed programmatically.
Auto-generated RDS password
Terraform generates a 24-character random password for RDS at apply time using the random provider. The password is never visible in code and never stored locally.
AWS Secrets Manager
The full RDS connection string — host, port, username, password, database name — is stored in Secrets Manager. Instances retrieve credentials at boot using their IAM role. Rotating credentials requires one Secrets Manager update and an instance refresh — no code changes.

Data Protection
Encryption at rest
All EBS volumes attached to EC2 instances are encrypted using gp3 with AES256. RDS storage is encrypted at rest. S3 buckets use server-side AES256 encryption. No data sits unencrypted anywhere in the stack.
S3 public access blocked
All S3 buckets — application assets and ALB logs — have public access fully blocked at the bucket and account level. No accidental public exposure is possible regardless of object ACLs.
S3 versioning and lifecycle
The application bucket has versioning enabled. Old non-current versions transition to S3 Standard-IA after 30 days and are permanently deleted after 90 days. This balances recovery capability with cost.

Infrastructure State Security
Remote state — encrypted and locked
Terraform state is stored in an encrypted S3 bucket, not on a local machine. DynamoDB state locking prevents two engineers from running terraform apply simultaneously, which could corrupt state or create duplicate resources.
State contains sensitive values
Terraform state can contain sensitive outputs. The state bucket has versioning enabled so any accidental corruption or deletion is recoverable. Access to the state bucket is controlled by IAM.

High Availability as a Security Property
Availability is a security concern. A single point of failure is a vulnerability.

Resources deployed across two availability zones — no single AZ failure takes down the application
RDS Multi-AZ with synchronous replication — automatic failover under 60 seconds, zero data loss
Auto Scaling Group with ELB health checks — unhealthy instances are replaced automatically
ALB health checks — traffic only routes to instances that pass /health checks
NAT Gateways in each AZ — outbound connectivity survives an AZ failure


What's Next

HTTPS with ACM certificate — TLS termination at the ALB, HTTP redirects to HTTPS
WAF — Layer 7 protection against SQL injection, XSS, and common web attacks
CloudTrail — full audit log of every API call made in the account
GuardDuty — threat detection for unusual access patterns and compromised credentials
VPC Flow Logs — network-level visibility for forensics and anomaly detection
Secrets rotation — automatic RDS password rotation on a schedule via Secrets Manager


Built as part of a 30-day AWS cloud infrastructure project — highfelabs/cloud-Infra-project