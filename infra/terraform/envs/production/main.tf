# =========================================================
# 1. VPC Configuration (Production)
# =========================================================
module "vpc" {
  source = "../../modules/vpc"

  vpc_name = "omnipayx-prod-vpc"
  vpc_cidr = "10.2.0.0/16"

  # 3 Availability Zones for maximum High Availability in Production
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
  public_subnets  = ["10.2.101.0/24", "10.2.102.0/24", "10.2.103.0/24"]

  # CRITICAL: Disable single NAT gateway. We need one NAT Gateway per AZ in Production
  # to ensure if one AZ goes down, outbound internet traffic still works.
  single_nat_gateway = false
}

# =========================================================
# 2. Security Groups
# =========================================================
resource "aws_security_group" "db_sg" {
  name        = "omnipayx-prod-db-sg"
  description = "Allow inbound traffic to RDS from within the VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

resource "aws_security_group" "cache_sg" {
  name        = "omnipayx-prod-cache-sg"
  description = "Allow inbound traffic to Redis from within the VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

resource "aws_security_group" "msk_sg" {
  name        = "omnipayx-prod-msk-sg"
  description = "Allow inbound traffic to MSK from within the VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  ingress {
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

# =========================================================
# 3. RDS (PostgreSQL)
# =========================================================
module "rds" {
  source = "../../modules/rds"

  identifier        = "omnipayx-prod-db"
  instance_class    = "db.t3.medium" # Upgraded instance for Production
  allocated_storage = 50             # More storage for Production

  db_name = "omnipayx_db"

  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  # CRITICAL: Multi-AZ must be true in Production for synchronous standby replica failover
  multi_az = true
}

# =========================================================
# 4. ElastiCache (Redis)
# =========================================================
module "elasticache" {
  source = "../../modules/elasticache"

  cluster_id      = "omnipayx-prod-redis"
  node_type       = "cache.t3.medium" # Upgraded instance for Production
  num_cache_nodes = 2                 # 2 nodes for High Availability

  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.cache_sg.id]
}

# =========================================================
# 5. MSK (Managed Kafka)
# =========================================================
module "msk" {
  source = "../../modules/msk"

  cluster_name              = "omnipayx-prod-kafka"
  number_of_broker_nodes    = 3                 # 3 brokers (one in each AZ)
  broker_node_instance_type = "kafka.t3.medium" # Better throughput
  ebs_volume_size           = 100

  client_subnets  = module.vpc.private_subnets
  security_groups = [aws_security_group.msk_sg.id]
}

# =========================================================
# 6. EKS (Elastic Kubernetes Service)
# =========================================================
module "eks" {
  source = "../../modules/eks"

  cluster_name    = "omnipayx-prod-cluster"
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}
