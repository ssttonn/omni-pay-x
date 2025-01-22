variable "identifier" {
  description = "The identifier for the DB instance"
  type        = string
}

variable "engine_version" {
  description = "The PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "The DB instance class (e.g., db.t3.micro)"
  type        = string
}

variable "allocated_storage" {
  description = "The allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "The name of the default database to create"
  type        = string
}

variable "username" {
  description = "The master username"
  type        = string
  default     = "dbadmin"
}

variable "subnet_ids" {
  description = "A list of private subnet IDs where the DB will be placed"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "A list of security group IDs to apply to the DB"
  type        = list(string)
}

variable "multi_az" {
  description = "Enable Multi-AZ for Production (High Availability)"
  type        = bool
  default     = false
}
