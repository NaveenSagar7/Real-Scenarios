resource "aws_iam_role" "webhook_instance_role" {
  name = "payflow-webhook-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "webhook_s3_write" {
  name = "payflow-webhook-s3-write"
  role = aws_iam_role.webhook_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::${var.s3_log_bucket_name}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "webhook_profile" {
  name = "payflow-webhook-instance-profile"
  role = aws_iam_role.webhook_instance_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.webhook_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}