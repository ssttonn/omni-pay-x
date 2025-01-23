# =========================================================
# 1. DB Subnet Group
# =========================================================
# This tells RDS which subnets it is allowed to place instances in.
resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.identifier}-subnet-group"
  }
}

# =========================================================
# 2. RDS Instance
# =========================================================
# The raw PostgreSQL database instance
resource "aws_db_instance" "this" {
  identifier        = var.identifier
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = var.db_name
  username = var.username

  # CRITICAL: This instructs AWS to automatically generate a secure password 
  # and store it in AWS Secrets Manager instead of putting it in plain text here!
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids

  # Controls whether the DB has a synchronous standby replica in another AZ
  multi_az = var.multi_az

  # For development/learning, we disable snapshots on deletion so it destroys cleanly
  skip_final_snapshot = true
  deletion_protection = false

  # Encrypt the database storage at rest using the default AWS KMS key
  storage_encrypted = true
}
