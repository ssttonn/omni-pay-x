output "db_instance_endpoint" {
  description = "The connection endpoint of the Database"
  value       = module.db.db_instance_endpoint
}

output "db_instance_name" {
  description = "The name of the database"
  value       = module.db.db_instance_name
}

output "db_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret containing the hidden Master Password"
  value       = module.db.db_instance_master_user_secret_arn
}
