output "api_url" {
  description = "Invoke URL for the deployed GET /students endpoint."
  value       = "${aws_api_gateway_stage.prod.invoke_url}${aws_api_gateway_resource.students.path}"
}

output "storage_bucket_name" {
  description = "S3 bucket used by the Lambda function."
  value       = aws_s3_bucket.storage_bucket.bucket
}

output "terraform_state_bucket_name" {
  description = "S3 bucket created for Terraform remote state bootstrap."
  value       = aws_s3_bucket.terraform_state_bucket.bucket
}

output "terraform_lock_table_name" {
  description = "DynamoDB table created for Terraform state locking."
  value       = aws_dynamodb_table.terraform_state_lock.name
}
