#!/bin/bash
# ─────────────────────────────────────────────
#  bootstrap-state.sh
#  Run this ONCE before terraform init
#  Creates the S3 bucket and DynamoDB table
#  needed for remote state storage
# ─────────────────────────────────────────────

set -e

REGION=${1:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="saas-infra-tfstate-${ACCOUNT_ID}"
TABLE_NAME="saas-infra-tf-locks"

echo "=== Bootstrapping Terraform Remote State ==="
echo "Region:     $REGION"
echo "Account ID: $ACCOUNT_ID"
echo "Bucket:     $BUCKET_NAME"
echo "DynamoDB:   $TABLE_NAME"
echo ""

# ─────────────────────────────────────────────
#  S3 Bucket
# ─────────────────────────────────────────────
echo "Creating S3 bucket..."

if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION"
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
fi

# Enable versioning — lets you recover previous state files
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'

# Block all public access
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Lifecycle rule — clean up old non-current state versions after _ days
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET_NAME" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "expire-old-state-versions",
      "Status": "Enabled",
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 2
      }
    }]
  }'

echo "✓ S3 bucket created: $BUCKET_NAME"

# ─────────────────────────────────────────────
#  DynamoDB Table — State Locking
#  Prevents two people running apply at once
# ─────────────────────────────────────────────
echo "Creating DynamoDB table..."

aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

echo "✓ DynamoDB table created: $TABLE_NAME"

# ─────────────────────────────────────────────
#  Output backend config to use in Terraform
# ─────────────────────────────────────────────
echo ""
echo "=== Bootstrap Complete ==="
echo ""
echo "Add this backend block to your environments/dev/main.tf:"
echo ""
echo 'terraform {'
echo '  backend "s3" {'
echo "    bucket         = \"$BUCKET_NAME\""
echo "    key            = \"dev/terraform.tfstate\""
echo "    region         = \"$REGION\""
echo "    dynamodb_table = \"$TABLE_NAME\""
echo '    encrypt        = true'
echo '  }'
echo '}'
echo ""
echo "Then run: terraform init"
