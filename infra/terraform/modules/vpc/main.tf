# =========================================================
# 1. VPC (Virtual Private Cloud)
# =========================================================
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
  }
}

# =========================================================
# 2. Public Subnets
# =========================================================
resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.azs[count.index]

  # Automatically assign public IPs to instances launched here
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.vpc_name}-public-${var.azs[count.index]}"
    "kubernetes.io/role/elb" = 1 # Required for EKS Public Load Balancers
  }
}

# =========================================================
# 3. Private Subnets
# =========================================================
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name                              = "${var.vpc_name}-private-${var.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = 1 # Required for EKS Internal Load Balancers
  }
}

# =========================================================
# 4. Internet Gateway (IGW) - For Public Internet Access
# =========================================================
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# =========================================================
# 5. Public Route Table (Routes traffic to the IGW)
# =========================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# =========================================================
# 6. Elastic IPs (EIPs) & NAT Gateways
# =========================================================
# Create 1 EIP if single_nat_gateway, else 1 EIP per AZ
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(var.azs)
  domain = "vpc"

  tags = {
    Name = var.single_nat_gateway ? "${var.vpc_name}-nat-eip" : "${var.vpc_name}-nat-eip-${var.azs[count.index]}"
  }
}

# Create NAT Gateways in the Public Subnets
resource "aws_nat_gateway" "this" {
  count         = var.single_nat_gateway ? 1 : length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id # Must be in a public subnet

  tags = {
    Name = var.single_nat_gateway ? "${var.vpc_name}-nat-gw" : "${var.vpc_name}-nat-gw-${var.azs[count.index]}"
  }

  # Ensure IGW exists before creating NAT Gateway
  depends_on = [aws_internet_gateway.this]
}

# =========================================================
# 7. Private Route Tables (Routes traffic to the NAT Gateway)
# =========================================================
# Create 1 route table if single_nat_gateway, else 1 per AZ
resource "aws_route_table" "private" {
  count  = var.single_nat_gateway ? 1 : length(var.azs)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = {
    Name = var.single_nat_gateway ? "${var.vpc_name}-private-rt" : "${var.vpc_name}-private-rt-${var.azs[count.index]}"
  }
}

# Associate private subnets with the correct private route table
resource "aws_route_table_association" "private" {
  count     = length(var.private_subnets)
  subnet_id = aws_subnet.private[count.index].id
  # If single NAT, point all private subnets to the first (and only) route table.
  # Otherwise, point each private subnet to its respective AZ's route table.
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}
