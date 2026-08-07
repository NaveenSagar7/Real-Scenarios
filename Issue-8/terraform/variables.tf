variable "aws_region" {
  default = "ap-south-1"
}

variable "project" {
  default = "finedge-transaction-audit"
}

variable "vpc_cidr" {
  default = "10.30.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.30.1.0/24", "10.30.2.0/24"]
}

variable "azs" {
  default = ["ap-south-1a", "ap-south-1b"]
}

variable "cluster_name" {
  default = "finedge-eks"
}

variable "namespace" {
  description = "Kubernetes namespace the workload runs in"
  default     = "fintech"
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount name used by the transaction-audit pods"
  default     = "transaction-audit"
}

variable "audit_bucket_name" {
  description = "S3 bucket the app writes audit records to"
  type        = string
}
