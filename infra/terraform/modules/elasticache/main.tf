# =========================================================
# 1. ElastiCache Subnet Group
# =========================================================
# Tells Redis which private subnets it is allowed to use.
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.cluster_id}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.cluster_id}-subnet-group"
  }
}

# =========================================================
# 2. ElastiCache Replication Group (Redis)
# =========================================================
# We use replication_group instead of cluster to support High Availability 
# (Primary with Replicas) when num_cache_nodes > 1.
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.cluster_id
  description          = "Redis replication group for ${var.cluster_id}"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.node_type
  port                 = 6379

  # Number of nodes (1 means no replica, 2 means 1 primary + 1 replica)
  num_cache_clusters = var.num_cache_nodes

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = var.vpc_security_group_ids

  # Security best practices
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false # Disabled for simpler local dev testing within VPC
}
