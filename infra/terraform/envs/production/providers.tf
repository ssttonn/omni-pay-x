provider "aws" {
  region = "us-east-1"
}

# Commented out backend for local testing without AWS account
# terraform {
#   backend "s3" {
#     bucket         = "omnipayx-terraform-state"
#     key            = "production/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "omnipayx-terraform-locks"
#   }
# }
