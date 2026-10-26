resource "aws_s3_bucket_lifecycle_configuration" "card_exchange" {
  bucket = aws_s3_bucket.card_exchange.id

  depends_on = [aws_s3_bucket_versioning.card_exchange]

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
