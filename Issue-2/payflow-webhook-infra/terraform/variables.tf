variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  default = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "azs" {
  default = ["us-east-1a", "us-east-1b"]
}

variable "instance_type" {
  default = "t3.micro"
}

variable "asg_min_size" {
  default = 2
}

variable "asg_max_size" {
  default = 4
}

variable "s3_log_bucket_name" {
  default = "payflow-webhook-logs"
}
