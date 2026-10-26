data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "config_evidence" {
  force_destroy = true
  bucket        = "portfolio-card-config-${data.aws_caller_identity.current.account_id}-ap-northeast-1"
  tags = {
    Project   = "aws-cicd-portfolio"
    Lifecycle = "persistent"
  }
}

resource "aws_s3_bucket_public_access_block" "config_evidence" {
  bucket                  = aws_s3_bucket.config_evidence.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_evidence" {
  bucket = aws_s3_bucket.config_evidence.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "config_evidence" {
  bucket = aws_s3_bucket.config_evidence.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "config_evidence" {
  bucket     = aws_s3_bucket.config_evidence.id
  depends_on = [aws_s3_bucket_versioning.config_evidence]
  rule {
    id     = "evidence-retention"
    status = "Enabled"
    filter {
      prefix = ""
    }
    expiration {
      days = 30
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "config_evidence" {
  bucket = aws_s3_bucket.config_evidence.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Deny", Principal = "*", Action = "s3:*"
        Resource  = [aws_s3_bucket.config_evidence.arn, "${aws_s3_bucket.config_evidence.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Effect    = "Allow", Principal = { Service = "config.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:ListBucket"]
        Resource  = aws_s3_bucket.config_evidence.arn
        Condition = { StringEquals = { "AWS:SourceAccount" = data.aws_caller_identity.current.account_id } }
      },
      {
        Effect   = "Allow", Principal = { Service = "config.amazonaws.com" }, Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.config_evidence.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
        Condition = { StringEquals = {
          "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          "s3:x-amz-acl"      = "bucket-owner-full-control"
        } }
      }
    ]
  })
}

