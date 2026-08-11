resource "aws_security_group" "app_sg" {
  name        = "billing-invoice-sg"
  description = "Allows inbound app traffic to the billing-invoice-service host"
  vpc_id      = data.aws_vpc.shared.id

  ingress {
    description = "App port from corp network"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.corp_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "billing-invoice-sg"
  }
}

resource "aws_instance" "app_host" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.public.ids[0]
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.app_instance_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y docker.io
    systemctl enable --now docker
  EOF

  tags = {
    Name    = "billing-invoice-service-host"
    Project = "billing-invoice-service"
    Role    = "app"
  }
}

output "app_host_id" {
  value = aws_instance.app_host.id
}

output "app_host_public_ip" {
  value = aws_instance.app_host.public_ip
}
