# Terraform Serverless Application on AWS

![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazonaws&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

A fully infrastructure-as-code serverless application on AWS, built with Terraform. The project provisions an API Gateway → Lambda → S3 pipeline from scratch, including remote state management with an S3 backend and DynamoDB state locking.

---

## What This Project Demonstrates

- **Infrastructure as Code** — Every AWS resource is defined and managed in Terraform HCL
- **Serverless architecture** — API Gateway + Lambda, no servers to manage
- **Secure IAM design** — Least-privilege roles and policies for Lambda
- **Remote state management** — S3 backend with DynamoDB state locking
- **Automated Lambda packaging** — Terraform's `archive_file` data source builds the zip automatically
- **Idempotent deployments** — `source_code_hash` and deployment triggers ensure consistent updates

---

## Architecture

```text
Client HTTP Request
        │
        ▼
 API Gateway REST API
  (GET /students)
        │
        ▼
 Lambda Proxy Integration
        │
        ▼
 Python Lambda Function
  (lambda_function.py)
        │
        ▼
  JSON Response
  + BUCKET_NAME env var
  read from S3
```

---

## AWS Resources Provisioned

| Resource | Purpose |
| --- | --- |
| `aws_api_gateway_rest_api` | REST API entry point |
| `aws_api_gateway_resource` | `/students` path |
| `aws_api_gateway_method` | Public `GET` method |
| `aws_api_gateway_integration` | Lambda proxy integration |
| `aws_api_gateway_deployment` | API deployment with change triggers |
| `aws_api_gateway_stage` | `prod` stage |
| `aws_lambda_function` | Python 3.12 function |
| `aws_iam_role` | Lambda execution role |
| `aws_iam_policy` | S3 read/write access for Lambda |
| `aws_iam_role_policy_attachment` x2 | Attaches S3 policy + CloudWatch logging |
| `aws_lambda_permission` | Scoped API Gateway → Lambda invoke permission |
| `aws_s3_bucket` | Application storage bucket |
| `aws_s3_bucket_public_access_block` | Blocks all public access to the bucket |
| `aws_s3_bucket` (state) | Terraform remote state bucket (bootstrap) |
| `aws_s3_bucket_versioning` | Versioning on the state bucket |
| `aws_dynamodb_table` | State locking table |

---

## Project Structure

```text
terraform-serverless-project/
├── providers.tf          # Terraform version + required providers
├── variables.tf          # Input variables
├── main.tf               # All AWS resource definitions
├── outputs.tf            # Deployment outputs (API URL, bucket names)
├── backend.tf            # Remote state backend (commented template)
├── .gitignore            # Excludes state files, zip files, credentials
├── README.md
└── lambda/
    └── lambda_function.py    # Lambda source (zip built automatically by Terraform)
```

---

## File Descriptions

### `providers.tf`

Declares the Terraform version and required providers:

- `aws` — creates and manages AWS resources
- `archive` — packages the Lambda Python file into a zip
- `random` — generates random suffixes for globally unique resource names

### `variables.tf`

| Variable | Default | Purpose |
| --- | --- | --- |
| `aws_region` | `us-east-1` | AWS region for deployment |
| `project_name` | `student-serverless` | Prefix used in all resource names |
| `bucket_name` | `null` | Optional custom S3 bucket name for the application |
| `state_bucket_name` | `null` | Optional custom S3 bucket name for Terraform state |
| `lock_table_name` | `null` | Optional custom DynamoDB table name for state locking |

When optional names are left as `null`, Terraform generates unique names using `project_name` and a random suffix.

### `main.tf`

Contains all AWS infrastructure resources. Key design choices:

- Uses `locals` to centralize repeated names, paths, and ARN expressions
- Uses `coalesce()` to allow optional overrides of generated resource names
- Uses `archive_file` data source so Terraform auto-packages the Lambda zip on every code change
- Uses `source_code_hash` so Lambda updates are detected and applied automatically
- Uses a scoped `aws_lambda_permission` with `source_arn` to restrict API Gateway access
- Uses `triggers` on `aws_api_gateway_deployment` so route or integration changes force a redeploy

### `outputs.tf`

| Output | Description |
| --- | --- |
| `api_url` | Full invoke URL for `GET /students` |
| `storage_bucket_name` | Application S3 bucket name |
| `terraform_state_bucket_name` | State bucket name (used to configure backend) |
| `terraform_lock_table_name` | DynamoDB lock table name (used to configure backend) |

### `backend.tf`

Contains a commented-out S3 backend template. The backend is intentionally left commented for the first deployment because Terraform cannot use an S3 backend bucket in the same run that creates it.

See [Migrating to Remote Terraform State](#migrating-to-remote-terraform-state) below.

### `lambda/lambda_function.py`

```python
import json
import os


def lambda_handler(event, context):
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(
            {
                "message": "Hello from Terraform Lambda!",
                "bucket": os.environ.get("BUCKET_NAME"),
            }
        ),
    }
```

Returns an HTTP 200 JSON response with a greeting message and the name of the application S3 bucket, passed through the `BUCKET_NAME` environment variable set by Terraform.

---

## Prerequisites

Install and configure the following before deploying:

- [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- An AWS account with permissions to create:
  - S3 buckets
  - IAM roles and policies
  - Lambda functions
  - API Gateway REST APIs
  - DynamoDB tables
  - CloudWatch Logs groups

Verify your setup:

```bash
terraform version
aws sts get-caller-identity
```

---

## Deployment

Run all commands from the project root directory:

```bash
cd terraform-serverless-project
```

**1. Initialize Terraform:**

```bash
terraform init
```

**2. Format and validate:**

```bash
terraform fmt
terraform validate
```

**3. Preview the execution plan:**

```bash
terraform plan
```

**4. Deploy:**

```bash
terraform apply
```

Type `yes` when prompted.

After a successful apply, Terraform prints the outputs:

```
api_url                    = "https://<id>.execute-api.us-east-1.amazonaws.com/prod/students"
storage_bucket_name        = "student-serverless-storage-<suffix>"
terraform_state_bucket_name = "student-serverless-tfstate-<suffix>"
terraform_lock_table_name   = "student-serverless-terraform-locks-<suffix>"
```

---

## Testing the API

Call the endpoint from the terminal:

```bash
# Linux / macOS
curl $(terraform output -raw api_url)

# Windows PowerShell
Invoke-RestMethod (terraform output -raw api_url)
```

Expected response:

```json
{
  "message": "Hello from Terraform Lambda!",
  "bucket": "student-serverless-storage-xxxxxxxx"
}
```

---

## Optional: Custom Resource Names

By default all resource names are auto-generated. To override:

```bash
terraform apply \
  -var="bucket_name=my-app-bucket" \
  -var="state_bucket_name=my-tfstate-bucket" \
  -var="lock_table_name=my-lock-table"
```

> S3 bucket names must be globally unique across all AWS accounts.

---

## Migrating to Remote Terraform State

The first `terraform apply` creates an S3 bucket and DynamoDB table that can store Terraform state remotely.

**Step 1 — Get the output values:**

```bash
terraform output terraform_state_bucket_name
terraform output terraform_lock_table_name
```

**Step 2 — Update `backend.tf`:**

Uncomment the backend block and fill in the values:

```hcl
terraform {
  backend "s3" {
    bucket         = "student-serverless-tfstate-xxxxxxxx"
    key            = "terraform-serverless-project/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "student-serverless-terraform-locks-xxxxxxxx"
    encrypt        = true
  }
}
```

**Step 3 — Migrate state:**

```bash
terraform init -migrate-state
```

Terraform will copy local state to S3 and enable DynamoDB state locking for all future runs.

---

## Updating the Lambda Function

1. Edit `lambda/lambda_function.py`
2. Run `terraform plan` to preview the change
3. Run `terraform apply`

Terraform rebuilds the zip automatically via the `archive_file` data source and detects code changes using `source_code_hash`.

---

## Cleaning Up

To destroy all AWS resources created by this project:

```bash
terraform destroy
```

Type `yes` when prompted.

> If S3 buckets contain objects, you may need to empty them before Terraform can delete them.

---

## Security

- **Do not commit** AWS credentials, `.tfvars` files containing secrets, or Terraform state files — these can contain sensitive values.
- This repo's `.gitignore` excludes `.terraform/`, `*.tfstate`, `*.tfvars`, Lambda zip files, and CSV files.
- The application S3 bucket has all public access blocked by default.
- The Lambda IAM policy follows least privilege — only `s3:GetObject` and `s3:PutObject` on the specific application bucket.

---

## Troubleshooting

| Problem | Solution |
| --- | --- |
| `terraform: command not found` | Install Terraform and add it to your `PATH` |
| `No credentials found` | Run `aws configure` or export `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` |
| `BucketAlreadyExists` | Leave `bucket_name` as `null` or choose a different unique name |
| API returns 403 / permission error | Confirm `aws_lambda_permission` was applied and `terraform apply` completed |
| Lambda changes not reflected | Run `terraform apply` — `source_code_hash` will detect the change |

---

## License

MIT — free to use, modify, and distribute.
