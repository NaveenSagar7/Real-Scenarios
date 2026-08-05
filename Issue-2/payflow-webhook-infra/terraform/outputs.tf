output "alb_dns_name" {
  value = aws_lb.webhook_alb.dns_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}
