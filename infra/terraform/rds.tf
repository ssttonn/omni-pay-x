module "db" {
  # Official AWS RDS module
  source  = "terraform-aws-modules/rds/aws"
  version = "6.1.1"

  # The unique identifier for the RDS instance in the AWS console
  identifier = "omnipayx-postgres"

  # Specify the database engine (PostgreSQL in this case)
  engine = "postgres"
  # Specify the exact engine version
  engine_version = "15.3"
  # Parameter group family
  family = "postgres15"
  # Major engine version for option groups
  major_engine_version = "15"
  # Hardware specifications for the DB instance (Baseline performance for moderate workloads)
  instance_class = "db.t3.medium"

  # Size of the hard drive (20 GB)
  allocated_storage = 20
  # Security best practice: Encrypt data at rest on the storage volume
  storage_encrypted = true

  # The initial logical database name to create
  db_name = "omnipayx"
  # The master administrator username
  username = "omnipayx_user"
  # The port PostgreSQL listens on
  port = 5432

  # ABSOLUTE SECURITY: Never hardcode passwords in Terraform. 
  # AWS will generate a cryptographically strong random password and lock it securely inside AWS Secrets Manager.
  manage_master_user_password = true

  # CLOUD MAGIC (HIGH AVAILABILITY): AWS maintains a synchronous "Standby" replica in another Availability Zone. 
  # If the Primary DB crashes, AWS auto-failovers to the Standby in seconds with zero data loss.
  multi_az = true

  # Attach the default security group from our VPC to control network rules
  vpc_security_group_ids = [module.vpc.default_security_group_id]

  # Lock the DB inside the Private Network. Even if the password leaks, 
  # hackers cannot connect from the outside Internet.
  subnet_ids = module.vpc.private_subnets

  # Required for Dev/LocalStack to allow instant deletion without taking a snapshot backup
  skip_final_snapshot = true
}
