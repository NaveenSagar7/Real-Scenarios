variable "aws_region" {
  default = "ap-south-1"
}

variable "project" {
  default = "streamly-catalog-api"
}

variable "vpc_cidr" {
  default = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "azs" {
  default = ["ap-south-1a", "ap-south-1b"]
}

variable "container_port" {
  description = "Port the ECS task listens on, per the task definition"
  default     = 8080
}

variable "ecr_repo_name" {
  default = "streamly-catalog-api"
}
