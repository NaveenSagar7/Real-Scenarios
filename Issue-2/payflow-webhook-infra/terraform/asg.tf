data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "webhook_lt" {
  name_prefix   = "payflow-webhook-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.webhook_profile.name
  }

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "webhook-processor starting" > /var/log/webhook-init.log
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "payflow-webhook-instance" }
  }
}

resource "aws_autoscaling_group" "webhook_asg" {
  name                = "payflow-webhook-asg"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_min_size
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.webhook_tg.arn]

  launch_template {
    id      = aws_launch_template.webhook_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "payflow-webhook-instance"
    propagate_at_launch = true
  }
}
