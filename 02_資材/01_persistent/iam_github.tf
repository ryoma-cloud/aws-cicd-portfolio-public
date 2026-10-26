# Application Auto Scaling target identifiers change whenever 02 is recreated.
# The provider reads tags even when no tags are configured on the target.
# ECSFullAccess omits this read action; EC2 AutoScalingFullAccess is a different API.
data "aws_caller_identity" "terraform" {}
data "aws_partition" "terraform" {}

data "aws_iam_role" "terraform" {
  name = "GitHubActionsTerraformPortfolioRole"
}

# Deployment support permissions share one customer managed policy attachment.
resource "aws_iam_policy" "terraform_scaling_metadata" {
  name        = "PortfolioTerraformScalingMetadataPolicy"
  description = "Read scalable target tags in the portfolio account and Tokyo region"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = ["application-autoscaling:ListTagsForResource"]
      Resource  = "arn:${data.aws_partition.terraform.partition}:application-autoscaling:ap-northeast-1:${data.aws_caller_identity.terraform.account_id}:scalable-target/*"
      Condition = { StringEquals = { "aws:RequestedRegion" = "ap-northeast-1" } }
      }, {
      Effect = "Allow"
      Action = [
        "cloudformation:CreateResource", "cloudformation:GetResource",
        "cloudformation:UpdateResource", "cloudformation:DeleteResource",
        "cloudformation:GetResourceRequestStatus", "cloudformation:CancelResourceRequest"
      ]
      Resource  = "*"
      Condition = { StringEquals = { "aws:RequestedRegion" = "ap-northeast-1" } }
    }]
  })
  tags = {
    Project   = "aws-cicd-portfolio"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_scaling_metadata" {
  role       = data.aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.terraform_scaling_metadata.arn
}
