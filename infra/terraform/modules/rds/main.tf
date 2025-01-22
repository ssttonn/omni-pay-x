module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier        = var.identifier
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name                     = var.db_name
  username                    = var.username
  manage_master_user_password = true

  db_subnet_group_name   = module.db_subnet2_group.name
  vpc_security_group_ids = var.vpc_security_group_ids

  multi_az = var.multi_az

  skip_final_snapshot = true
  deletion_protection = false
}

resource "aws_db_subnet_group" "default" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.identifier}-subnet-group"
  }
}
