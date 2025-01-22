output "redis_endpoint" {
  description = "The connection endpoint for Redis"
  value       = module.elasticache.cluster_cache_nodes[0].address
}

output "redis_port" {
  description = "The port for Redis"
  value       = module.elasticache.cluster_cache_nodes[0].port
}
