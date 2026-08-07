terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Partial backend config - supply the rest at init time:
  # terraform init \
  #   -backend-config="bucket=<state_bucket_name from bootstrap output>" \
  #   -backend-config="region=ap-south-1" \
  #   -backend-config="dynamodb_table=streamly-terraform-locks"
  backend "s3" {
    key     = "issue-007/terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}
