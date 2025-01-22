variable "cluster_id" {
  description = "The identifier for the ElastiCache cluster"
  type        = string
}

variable "node_type" {
  description = "The compute and memory capacity of the nodes (e.g., cache.t3.micro)"
  type        = string
}

variable "num_cache_nodes" {
  description = "The number of cache nodes that the cache cluster should have"
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "A list of private subnet IDs where the Redis cluster will be placed"
  type        = list(string)
}
variable "vpc_security_group_ids" {
  description = "A list of security group IDs to apply to the Redis cluster"
  type        = list(string)
}
