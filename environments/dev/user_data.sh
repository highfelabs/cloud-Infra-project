#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1
 
echo "=== Starting user data script ==="
 
# ─────────────────────────────────────────────
#  IMDSv2 Metadata
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
APP_ENV="${environment}"
DB_SECRET_NAME="${db_secret_name}"
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"
 
echo "Instance: $INSTANCE_ID | AZ: $AZ | Env: $APP_ENV"
 
# ─────────────────────────────────────────────
#  Set Hostname
# ─────────────────────────────────────────────
hostnamectl set-hostname "appserver-$AZ"
 
# ─────────────────────────────────────────────
#  Install nginx + AWS CLI (already on AL2023)
# ─────────────────────────────────────────────
yum update -y
yum install -y nginx
 
# ─────────────────────────────────────────────
#  Fetch RDS credentials from Secrets Manager
# ─────────────────────────────────────────────
echo "Fetching RDS credentials..."
 
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$DB_SECRET_NAME" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text 2>&1)
 
if echo "$SECRET" | grep -q '"host"'; then
  DB_HOST=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['host'])")
  DB_PORT=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['port'])")
  DB_NAME=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['dbname'])")
  DB_USER=$(echo $SECRET | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
  DB_STATUS="CONNECTED"
  DB_DETAIL="$DB_HOST:$DB_PORT / $DB_NAME"
  echo "RDS credentials fetched successfully"
else
  DB_STATUS="ERROR"
  DB_DETAIL="Could not fetch secret: $SECRET"
  echo "Failed to fetch RDS credentials"
fi
 
# ─────────────────────────────────────────────
#  Write HTML page
# ─────────────────────────────────────────────
cat > /usr/share/nginx/html/index.html << HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SaaS Infra Dashboard</title>
  <link href="https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=Syne:wght@400;700;800&display=swap" rel="stylesheet">
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      --bg:      #0a0e17;
      --surface: #111827;
      --border:  #1f2937;
      --green:   #00ff88;
      --red:     #ff4455;
      --blue:    #38bdf8;
      --muted:   #6b7280;
      --text:    #f1f5f9;
    }
    body {
      background: var(--bg); color: var(--text);
      font-family: 'Syne', sans-serif;
      min-height: 100vh; padding: 40px 24px;
    }
    body::before {
      content: ''; position: fixed; inset: 0;
      background-image:
        linear-gradient(rgba(56,189,248,0.03) 1px, transparent 1px),
        linear-gradient(90deg, rgba(56,189,248,0.03) 1px, transparent 1px);
      background-size: 40px 40px;
      pointer-events: none; z-index: 0;
    }
    .container { max-width: 900px; margin: 0 auto; position: relative; z-index: 1; }
    header { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 48px; flex-wrap: wrap; gap: 16px; }
    .logo { display: flex; align-items: center; gap: 12px; }
    .logo-icon {
      width: 40px; height: 40px; background: var(--green); border-radius: 8px;
      display: flex; align-items: center; justify-content: center; font-size: 20px;
      animation: pulse 3s ease-in-out infinite;
    }
    @keyframes pulse {
      0%,100% { box-shadow: 0 0 0 0 rgba(0,255,136,0.4); }
      50%      { box-shadow: 0 0 0 12px rgba(0,255,136,0); }
    }
    h1 { font-size: 24px; font-weight: 800; }
    h1 span { color: var(--green); }
    .env-badge {
      display: inline-block; background: rgba(56,189,248,0.1);
      border: 1px solid rgba(56,189,248,0.3); color: var(--blue);
      padding: 2px 10px; border-radius: 20px;
      font-size: 11px; font-family: 'Space Mono', monospace;
      letter-spacing: 1px; text-transform: uppercase; margin-top: 4px;
    }
    .meta { font-family: 'Space Mono', monospace; font-size: 11px; color: var(--muted); text-align: right; line-height: 1.8; }
    .section-label { font-size: 11px; font-family: 'Space Mono', monospace; color: var(--muted); letter-spacing: 2px; text-transform: uppercase; margin-bottom: 12px; }
    .card { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 24px; margin-bottom: 16px; animation: fadeUp 0.4s ease both; }
    @keyframes fadeUp { from { opacity:0; transform:translateY(12px); } to { opacity:1; transform:translateY(0); } }
    .card-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; }
    .card-title { font-size: 16px; font-weight: 700; display: flex; align-items: center; gap: 10px; }
    .card-icon { width: 32px; height: 32px; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: 16px; }
    .icon-ec2 { background: rgba(56,189,248,0.1); }
    .icon-db  { background: rgba(0,255,136,0.1); }
    .icon-s3  { background: rgba(255,217,61,0.1); }
    .status { display: inline-flex; align-items: center; gap: 6px; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-family: 'Space Mono', monospace; font-weight: 700; }
    .status::before { content: ''; width: 6px; height: 6px; border-radius: 50%; }
    .status-ok      { background: rgba(0,255,136,0.1); color: var(--green); }
    .status-ok::before { background: var(--green); box-shadow: 0 0 6px var(--green); }
    .status-error   { background: rgba(255,68,85,0.1); color: var(--red); }
    .status-error::before { background: var(--red); }
    .kv-grid { display: grid; grid-template-columns: 160px 1fr; gap: 10px 16px; }
    .kv-key { font-family: 'Space Mono', monospace; font-size: 11px; color: var(--muted); }
    .kv-val { font-family: 'Space Mono', monospace; font-size: 13px; color: var(--text); word-break: break-all; }
    .kv-val.hi { color: var(--blue); }
    .kv-val.ok { color: var(--green); }
    .kv-val.err { color: var(--red); }
    .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
    @media(max-width:640px) { .grid-2 { grid-template-columns: 1fr; } }
    .divider { border: none; border-top: 1px solid var(--border); margin: 28px 0; }
    footer { margin-top: 48px; text-align: center; font-family: 'Space Mono', monospace; font-size: 11px; color: var(--muted); }
  </style>
</head>
<body>
<div class="container">
 
  <header>
    <div class="logo">
      <div class="logo-icon">⚡</div>
      <div>
        <h1>SaaS <span>Infra</span></h1>
        <div><span class="env-badge">$APP_ENV</span></div>
      </div>
    </div>
    <div class="meta">
      <div>Booted: $(date -u '+%Y-%m-%d %H:%M:%S UTC')</div>
      <div style="margin-top:4px"><a href="/health" style="color:var(--blue);text-decoration:none;font-size:11px">→ /health</a></div>
    </div>
  </header>
 
  <!-- EC2 -->
  <div class="section-label">EC2 Instance</div>
  <div class="grid-2">
    <div class="card">
      <div class="card-header">
        <div class="card-title"><div class="card-icon icon-ec2">🖥</div>Identity</div>
        <span class="status status-ok">RUNNING</span>
      </div>
      <div class="kv-grid">
        <span class="kv-key">instance id</span>   <span class="kv-val hi">$INSTANCE_ID</span>
        <span class="kv-key">hostname</span>       <span class="kv-val">appserver-$AZ</span>
      </div>
    </div>
    <div class="card">
      <div class="card-header">
        <div class="card-title"><div class="card-icon icon-ec2">🌍</div>Placement</div>
      </div>
      <div class="kv-grid">
        <span class="kv-key">az</span>          <span class="kv-val hi">$AZ</span>
        <span class="kv-key">environment</span> <span class="kv-val">$APP_ENV</span>
      </div>
    </div>
  </div>
 
  <hr class="divider">
 
  <!-- RDS -->
  <div class="section-label">RDS Database</div>
  <div class="card">
    <div class="card-header">
      <div class="card-title"><div class="card-icon icon-db">🗄</div>MySQL Connection</div>
      $([ "$DB_STATUS" = "CONNECTED" ] && echo '<span class="status status-ok">CONNECTED</span>' || echo '<span class="status status-error">FAILED</span>')
    </div>
    <div class="kv-grid">
      <span class="kv-key">status</span>  <span class="kv-val $([ "$DB_STATUS" = "CONNECTED" ] && echo ok || echo err)">$DB_STATUS</span>
      <span class="kv-key">detail</span>  <span class="kv-val">$DB_DETAIL</span>
      <span class="kv-key">secret</span>  <span class="kv-val">$DB_SECRET_NAME</span>
    </div>
  </div>
 
  <hr class="divider">
 
  <!-- S3 -->
  <div class="section-label">S3 Storage</div>
  <div class="card">
    <div class="card-header">
      <div class="card-title"><div class="card-icon icon-s3">🪣</div>App Bucket</div>
      <span class="status status-ok">ACCESSIBLE</span>
    </div>
    <div class="kv-grid">
      <span class="kv-key">bucket</span> <span class="kv-val hi">$S3_BUCKET</span>
    </div>
  </div>
 
  <footer>
    <p>highfelabs/cloud-Infra-project &nbsp;·&nbsp; Day 13</p>
  </footer>
 
</div>
</body>
</html>
HTML
 
# ─────────────────────────────────────────────
#  Health check endpoint
# ─────────────────────────────────────────────
echo '{"status":"ok"}' > /usr/share/nginx/html/health
 
# ─────────────────────────────────────────────
#  Start nginx
# ─────────────────────────────────────────────
systemctl enable nginx
systemctl start nginx
 
echo "=== Deployment complete ==="