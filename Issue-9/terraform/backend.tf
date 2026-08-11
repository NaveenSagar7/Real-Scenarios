terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "vantra-terraform-state"
    key            = "billing-invoice-service/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "vantra-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "billing-invoice-service"
      Environment = var.environment
      ManagedBy   = "terraform"
      Company     = "vantra"
    }
  }
}
