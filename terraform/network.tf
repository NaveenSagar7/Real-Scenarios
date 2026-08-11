data "aws_vpc" "shared" {
  filter {
    name   = "tag:Name"
    values = ["vantra-shared-vpc"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.shared.id]
  }
  tags = {
    Tier = "public"
  }
}
