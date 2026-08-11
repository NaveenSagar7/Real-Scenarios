variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "corp_cidr" {
  description = "CIDR allowed to reach the app port directly for testing/support"
  type        = string
  default     = "10.0.99.0/24"
}

variable "ami_id" {
  description = "AMI id used for both the app host and Jenkins controller. Confirm what OS this resolves to in your account/region (aws ec2 describe-images --image-ids <id>) before assuming apt vs dnf in user_data."
  type        = string
  default     = "ami-0f58b397bc5c1f2e8"
}
