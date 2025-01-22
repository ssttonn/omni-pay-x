# =========================================================
# 1. VPC Configuration
# =========================================================
module "vpc" {
  source = "../../modules/vpc"

  vpc_name = "omnipayx-staging-vpc"
  vpc_cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  single_nat_gateway = true
}

# =========================================================
# 2. Security Groups
# =========================================================
resource "aws_security_group" "db_sg" {
  name        = "omnipayx-staging-db-sg"
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
  name        = "omnipayx-staging-cache-sg"
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
  name        = "omnipayx-staging-msk-sg"
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

  identifier     = "omnipayx-staging-db"
  instance_class = "db.t3.micro"

  db_name = "omnipayx_db"

  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.db_sg.id]
}

# =========================================================
# 4. ElastiCache (Redis)
# =========================================================
module "elasticache" {
  source = "../../modules/elasticache"

  cluster_id = "omnipayx-staging-redis"
  node_type  = "cache.t3.micro"

  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.cache_sg.id]
}

# =========================================================
# 5. MSK (Managed Kafka)
# =========================================================
module "msk" {
  source = "../../modules/msk"

  cluster_name              = "omnipayx-staging-kafka"
  broker_node_instance_type = "kafka.t3.small"

  client_subnets  = module.vpc.private_subnets
  security_groups = [aws_security_group.msk_sg.id]
}

# =========================================================
# 6. EKS (Elastic Kubernetes Service)
# =========================================================
module "eks" {
  source = "../../modules/eks"

  cluster_name    = "omnipayx-staging-cluster"
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}
