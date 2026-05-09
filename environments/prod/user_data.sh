#!/bin/bash
# Fetch instance metadata (IMDSv2)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Set hostname
hostnamectl set-hostname "appserver-${AZ}"

# Write identity file
cat > /etc/server-info.txt <<EOF
Instance ID: ${INSTANCE_ID}
AZ:          ${AZ}
EOF

# Install your app dependencies
yum update -y
yum install -y nginx

# Start and enable nginx
systemctl start nginx
systemctl enable nginx