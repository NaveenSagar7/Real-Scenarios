terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    # Fill these in (or pass via -backend-config) after running terraform/backend:
    # bucket         = "<state_bucket output>"
    # key            = "meter-reading-service/infra.tfstate"
    # region         = "ap-south-1"
    # dynamodb_table = "<lock_table output>"
  }
}
