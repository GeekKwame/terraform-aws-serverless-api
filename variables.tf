variable "aws_region" {
  description = "AWS region where the serverless application will be deployed."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used for named AWS resources."
  type        = string
  default     = "student-serverless"
}

variable "bucket_name" {
  description = "Optional globally unique S3 bucket name for application storage."
  type        = string
  default     = null
}

variable "state_bucket_name" {
  description = "Optional globally unique S3 bucket name for Terraform remote state bootstrap."
  type        = string
  default     = null
}

variable "lock_table_name" {
  description = "Optional DynamoDB table name for Terraform state locking."
  type        = string
  default     = null
}
