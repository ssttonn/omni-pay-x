variable "cluster_name" {
  description = "The name of the MSK cluster"
  type        = string
}

variable "kafka_version" {
  description = "The Apache Kafka version"
  type        = string
  default     = "3.5.1"
}

variable "number_of_broker_nodes" {
  description = "The desired total number of broker nodes in the kafka cluster"
  type        = number
  default     = 2 # Must be a multiple of the number of AZs (subnets)
}

variable "broker_node_instance_type" {
  description = "The instance type to use for the Kafka brokers (e.g., kafka.t3.small)"
  type        = string
}

variable "ebs_volume_size" {
  description = "The size in GiB of the EBS volume for the data drive on each broker node"
  type        = number
  default     = 20
}

variable "client_subnets" {
  description = "A list of private subnets to connect to in client VPC"
  type        = list(string)
}

variable "security_groups" {
  description = "A list of security groups to associate with the Elastic Network Interfaces to control who can communicate with the MSK cluster"
  type        = list(string)
}
