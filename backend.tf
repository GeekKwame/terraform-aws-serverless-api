# Remote State Backend Configuration
#
# This backend block is intentionally commented out for first-time deployment.
#
# Terraform cannot use an S3 backend during the same run that creates the bucket.
# Workflow:
#   1. Run `terraform apply` with local state (backend commented out).
#   2. Get the bucket and table names from the terraform outputs:
#        terraform output terraform_state_bucket_name
#        terraform output terraform_lock_table_name
#   3. Paste those values below and uncomment the block.
#   4. Run `terraform init -migrate-state` to move state to S3.
#
# terraform {
#   backend "s3" {
#     bucket         = "<your-tfstate-bucket-name>"
#     key            = "terraform-serverless-project/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "<your-lock-table-name>"
#     encrypt        = true
#   }
# }
