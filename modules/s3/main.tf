# ─────────────────────────────────────────────
#  S3 App Bucket
#  General purpose bucket for app assets,
#  uploads, and static files
# ─────────────────────────────────────────────
resource "aws_s3_bucket" "app" {
  bucket = "${var.name}-app-${var.bucket_suffix}"

  tags = merge(var.tags, { Name = "${var.name}-app-bucket" })
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  rule {
    id     = "expire-incomplete-multipart"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ─────────────────────────────────────────────
#  S3 ALB Logs Bucket
#  Separate bucket for ALB access logs
#  Requires specific bucket policy for ALB
# ─────────────────────────────────────────────
resource "aws_s3_bucket" "alb_logs" {
  count  = var.create_alb_logs_bucket ? 1 : 0
  bucket = "${var.name}-alb-logs-${var.bucket_suffix}"

  tags = merge(var.tags, { Name = "${var.name}-alb-logs-bucket" })
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  count  = var.create_alb_logs_bucket ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  count  = var.create_alb_logs_bucket ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  count  = var.create_alb_logs_bucket ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = var.alb_logs_retention_days
    }
  }
}

# ALB needs permission to write logs to this bucket
data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "alb_logs" {
  count  = var.create_alb_logs_bucket ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowALBLogDelivery"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/${var.name}-alb/AWSLogs/*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
#  IAM Policy — App Server S3 Access
#  Attach to the EC2 instance role so app
#  servers can read/write the app bucket
# ─────────────────────────────────────────────
resource "aws_iam_policy" "app_s3_access" {
  name        = "${var.name}-s3-access-policy"
  description = "Allows EC2 app servers to read and write the app S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AppBucketReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app.arn,
          "${aws_s3_bucket.app.arn}/*"
        ]
      }
    ]
  })

  tags = var.tags
}
