terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }

  # terraform init \
  #   -backend-config="bucket=<state_bucket_name from bootstrap output>" \
  #   -backend-config="region=ap-south-1" \
  #   -backend-config="dynamodb_table=finedge-eks-terraform-locks"
  backend "s3" {
    key     = "issue-008/terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate  = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                   = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  repository_cache       = "${path.module}/.helm-cache"
  repository_config_path = "${path.module}/.helm-cache/repositories.yaml"

  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}
