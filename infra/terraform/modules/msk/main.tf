resource "aws_msk_cluster" "kafka" {
  cluster_name  = var.cluster_name
  kafka_version = var.kafka_version

  # Number of broker nodes must be a multiple of the number of AZs
  number_of_broker_nodes = var.number_of_broker_nodes

  broker_node_group_info {
    instance_type = var.broker_node_instance_type

    # Place brokers in private subnets for security
    client_subnets  = var.client_subnets
    security_groups = var.security_groups

    storage_info {
      ebs_storage_info {
        volume_size = var.ebs_volume_size
      }
    }
  }

  client_authentication {
    # Allows PLAINTEXT connections within the VPC. 
    # In a strict production environment, this should be false, and IAM/TLS should be used.
    unauthenticated = true
  }

  # Enable PLAINTEXT communication for simplicity (default is TLS)
  encryption_info {
    encryption_in_transit {
      client_broker = "PLAINTEXT"
      in_cluster    = true
    }
  }
}
