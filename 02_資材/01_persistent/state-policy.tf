# Normal apply forgets legacy backend-policy registration without deleting AWS policy.
# Terraform destroy ignores this retention intent; tools._05_environment blocks it while legacy State exists.
# New environments configure the retained backend policy outside the environment State.
removed {
  from = aws_s3_bucket_policy.state_tls
  lifecycle {
    destroy = false
  }
}
