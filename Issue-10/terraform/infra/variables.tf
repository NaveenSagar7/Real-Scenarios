variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project" {
  type    = string
  default = "vantra-meter-reading"
}

variable "cluster_name" {
  type    = string
  default = "vantra-shared-eks"
}

variable "k8s_namespace" {
  description = "Namespace the meter-reading-service Helm release is installed into"
  type        = string
  default     = "vantra-billing"
}

variable "service_account_name" {
  description = "Name of the Kubernetes ServiceAccount used by meter-reading-service"
  type        = string
  default     = "meter-reading-service"
}
