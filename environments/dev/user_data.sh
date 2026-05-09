#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "=== Starting user data script ==="

# ─────────────────────────────────────────────
#  IMDSv2 Token
# ─────────────────────────────────────────────
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

# ─────────────────────────────────────────────
#  Injected by Terraform templatefile()
# ─────────────────────────────────────────────
ENVIRONMENT="${environment}"
DB_SECRET_NAME="${db_secret_name}"
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"

echo "Instance ID:  $INSTANCE_ID"
echo "AZ:           $AZ"
echo "Environment:  $ENVIRONMENT"
echo "DB Secret:    $DB_SECRET_NAME"
echo "S3 Bucket:    $S3_BUCKET"

# ─────────────────────────────────────────────
#  Set Hostname
# ─────────────────────────────────────────────
hostnamectl set-hostname "appserver-$AZ"

# ─────────────────────────────────────────────
#  Fetch RDS Credentials from Secrets Manager
# ─────────────────────────────────────────────
echo "Fetching RDS credentials from Secrets Manager..."

SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$DB_SECRET_NAME" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)

DB_HOST=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['host'])")
DB_PORT=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['port'])")
DB_NAME=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['dbname'])")
DB_USER=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
DB_PASS=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

echo "RDS host resolved: $DB_HOST"

# Write app environment config (adjust path to your app)
cat > /etc/app.env <<EOF
APP_ENV=$ENVIRONMENT
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
S3_BUCKET=$S3_BUCKET
AWS_REGION=$AWS_REGION
EOF

chmod 600 /etc/app.env
echo "App environment written to /etc/app.env"

# ─────────────────────────────────────────────
#  Install nginx
# ─────────────────────────────────────────────
yum update -y
yum install -y nginx

# ─────────────────────────────────────────────
#  Write webpage
# ─────────────────────────────────────────────
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Server Info</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f4f4; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
    .card { background: white; padding: 40px 60px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); text-align: center; }
    h1 { color: #232f3e; margin-bottom: 8px; }
    .badge { display: inline-block; background: #ff9900; color: white; padding: 6px 16px; border-radius: 20px; font-size: 14px; margin-bottom: 24px; }
    .env { display: inline-block; background: #232f3e; color: white; padding: 4px 12px; border-radius: 20px; font-size: 12px; margin-left: 8px; }
    table { border-collapse: collapse; width: 100%; }
    td { padding: 10px 16px; text-align: left; border-bottom: 1px solid #eee; }
    td:first-child { font-weight: bold; color: #555; width: 160px; }
    td:last-child { color: #232f3e; font-family: monospace; font-size: 14px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🖥️ Server Info <span class="env">$ENVIRONMENT</span></h1>
    <div class="badge">AWS EC2</div>
    <table>
      <tr><td>Instance ID</td><td>$INSTANCE_ID</td></tr>
      <tr><td>Availability Zone</td><td>$AZ</td></tr>
      <tr><td>Hostname</td><td>appserver-$AZ</td></tr>
      <tr><td>Database</td><td>$DB_HOST:$DB_PORT / $DB_NAME</td></tr>
      <tr><td>S3 Bucket</td><td>$S3_BUCKET</td></tr>
    </table>
  </div>
</body>
</html>
EOF

# Write health check endpoint
mkdir -p /usr/share/nginx/html
echo '{"status":"ok"}' > /usr/share/nginx/html/health

systemctl start nginx
systemctl enable nginx

echo "=== User data complete ==="