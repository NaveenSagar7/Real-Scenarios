data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_instance_role" {
  name               = "billing-invoice-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# SSM access so the pipeline can push deploy commands with no SSH/bastion.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.app_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Lets the host authenticate to ECR and pull the image the pipeline pushed.
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.app_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "app_instance_profile" {
  name = "billing-invoice-instance-profile"
  role = aws_iam_role.app_instance_role.name
}
