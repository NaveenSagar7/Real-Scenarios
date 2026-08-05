resource "aws_lb" "webhook_alb" {
  name               = "payflow-webhook-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = { Name = "payflow-webhook-alb" }
}

resource "aws_lb_target_group" "webhook_tg" {
  name     = "payflow-webhook-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = { Name = "payflow-webhook-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.webhook_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webhook_tg.arn
  }
}
