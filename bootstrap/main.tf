terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Local state on purpose - this stack creates the remote backend
  # that every other stack in this repo depends on.
}

provider "aws" {
  region = "ap-south-1"
}

# ---------- Terraform remote state backend ----------

resource "aws_s3_bucket" "tf_state" {
  bucket = "vantra-terraform-state"
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "vantra-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ---------- Shared VPC ----------

resource "aws_vpc" "shared" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vantra-shared-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.shared.id
  tags = {
    Name = "vantra-shared-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.shared.id
  cidr_block              = "10.20.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "vantra-public-${count.index}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.shared.id
  cidr_block        = "10.20.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "vantra-private-${count.index}"
    Tier = "private"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "vantra-shared-nat"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.shared.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "vantra-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.shared.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "vantra-private-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ---------- Outputs ----------

output "vpc_id" {
  value = aws_vpc.shared.id
}
