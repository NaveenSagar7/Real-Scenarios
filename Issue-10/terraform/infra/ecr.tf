resource "aws_ecr_repository" "meter_reading_service" {
  name                 = "${var.project}/meter-reading-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.meter_reading_service.repository_url
}
