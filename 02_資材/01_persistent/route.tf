resource "aws_route_table" "public" {
  vpc_id = aws_vpc.portfolio.id

  tags = {
    Name        = "portfolio-public-rt"
    Project     = "aws-cicd-portfolio"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.portfolio.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.portfolio.id

  tags = {
    Name        = "portfolio-private-rt"
    Project     = "aws-cicd-portfolio"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

