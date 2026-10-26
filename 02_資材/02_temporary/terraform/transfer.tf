provider "awscc" {
  region = "ap-northeast-1"
}

# Cloud Control exposes max_concurrent_connections, absent from aws 6.67.0.
resource "awscc_transfer_connector" "vendor" {
  depends_on = [aws_iam_role_policy_attachment.transfer]

  access_role          = aws_iam_role.transfer.arn
  url                  = "sftp://${aws_eip.vendor.public_ip}:22"
  security_policy_name = "TransferSFTPConnectorSecurityPolicy-2024-03"
  logging_role         = aws_iam_role.transfer_logging.arn

  sftp_config = {
    user_secret_id             = aws_secretsmanager_secret.sftp.arn
    trusted_host_keys          = var.sftp_host_keys
    max_concurrent_connections = 1
  }
}

resource "aws_security_group_rule" "vendor_sftp" {
  type              = "ingress"
  security_group_id = aws_security_group.vendor.id
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = [for ip in awscc_transfer_connector.vendor.service_managed_egress_ip_addresses : "${ip}/32"]
  description       = "portfolio-connector"
}

resource "aws_instance" "vendor" {
  ami                         = data.aws_ssm_parameter.ami.value
  instance_type               = "t3.micro"
  subnet_id                   = sort(data.aws_subnets.public.ids)[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.vendor.id]
  iam_instance_profile        = aws_iam_instance_profile.vendor.name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }

  depends_on = [
    aws_iam_role_policy_attachment.vendor_ssm,
    aws_vpc_security_group_egress_rule.vendor_https
  ]
}

resource "aws_eip" "vendor" {
  domain   = "vpc"
  instance = aws_instance.vendor.id

  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
    Lifecycle = "temporary"
  }
}

