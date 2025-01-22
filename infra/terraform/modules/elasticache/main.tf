module "elasticache" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 1.2"

  cluster_id = var.cluster_id

  engine          = "redis"
  engine_version  = "7.0"
  node_type       = var.node_type
  num_cache_nodes = var.num_cache_nodes
  port            = 6379

  subnet_group_name  = aws_elasticache_subnet_group.default.name
  security_group_ids = var.vpc_security_group_ids

  at_rest_encryption_enabled = true
  transit_encryption_enabled = false
}

resource "aws_elasticache_subnet_group" "default" {
  name       = "${var.cluster_id}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.cluster_id}-subnet-group"
  }
}
