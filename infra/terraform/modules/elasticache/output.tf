output "redis_endpoint" {
  description = "The endpoint of the Redis cluster"
  # If clustered (num_cache_clusters > 1), we return the primary endpoint.
  # Otherwise, we return the single node endpoint.
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "redis_port" {
  description = "The port of the Redis cluster"
  value       = aws_elasticache_replication_group.this.port
}
