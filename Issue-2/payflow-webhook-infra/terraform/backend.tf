terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "payfloww-tfstate-us-east-1"
    key            = "webhook-processor/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "payflow-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
