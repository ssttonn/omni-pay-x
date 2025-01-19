resource "aws_msk_cluster" "kafka" {
  # The name of the Managed Kafka cluster
  cluster_name = "omnipayx-kafka"
  # The Apache Kafka software version
  kafka_version = "3.4.0"

  # EVENT-DRIVEN GOLDEN RULE: Kafka MUST NOT DIE. 
  # Distributing 2 brokers across 2 different Data Centers ensures the message bus survives a full Data Center outage.
  number_of_broker_nodes = 2

  broker_node_group_info {
    # The hardware specifications for each Kafka broker
    instance_type = "kafka.t3.small"

    # Place the brokers into our highly secure Private Subnets
    client_subnets = module.vpc.private_subnets

    # Attach the VPC's default security group to allow internal traffic
    security_groups = [module.vpc.default_security_group_id]
  }

  client_authentication {
    # In a real Production environment, this must be switched to IAM or SASL/SCRAM authentication. 
    # Temporarily enabled (True) to remain fully compatible with our local Java code which currently lacks auth configuration.
    unauthenticated = true
  }

  # Tag the resource for cost-tracking and management purposes
  tags = {
    Environment = "Production"
  }
}
