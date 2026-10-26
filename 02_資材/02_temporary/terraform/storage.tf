resource "aws_s3_bucket" "card_exchange" {
  bucket        = "portfolio-card-exchange-${data.aws_caller_identity.current.account_id}-ap-northeast-1"
  force_destroy = true

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

resource "aws_s3_bucket_public_access_block" "card_exchange" {
  bucket = aws_s3_bucket.card_exchange.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "card_exchange" {
  bucket = aws_s3_bucket.card_exchange.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "card_exchange" {
  bucket = aws_s3_bucket.card_exchange.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "tls" {
  bucket = aws_s3_bucket.card_exchange.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.card_exchange.arn,
        "${aws_s3_bucket.card_exchange.arn}/*"
      ]
      Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })
}
