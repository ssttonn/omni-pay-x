output "bootstrap_brokers_plaintext" {
  description = "A comma separated list of one or more hostname:port pairs of kafka brokers suitable to bootstrap connectivity to the kafka cluster"
  value       = aws_msk_cluster.kafka.bootstrap_brokers
}

output "zookeeper_connect_string" {
  description = "A comma separated list of one or more IP:port pairs to use to connect to the Apache Zookeeper cluster"
  value       = aws_msk_cluster.kafka.zookeeper_connect_string
}
