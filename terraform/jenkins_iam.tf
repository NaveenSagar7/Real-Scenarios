data "aws_iam_policy_document" "jenkins_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins_role" {
  name               = "vantra-jenkins-controller-role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume_role.json
}

resource "aws_iam_role_policy_attachment" "jenkins_ssm_core" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "jenkins_pipeline" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
    ]
    resources = [aws_ecr_repository.billing_invoice_service.arn]
  }
  statement {
    sid = "SsmDeploy"
    actions = [
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
      "ssm:DescribeInstanceInformation",
    ]
    resources = ["*"]
  }
  statement {
    sid       = "TfStateRead"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::vantra-terraform-state/*"]
  }
  statement {
    sid       = "TfStateList"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::vantra-terraform-state"]
  }
  statement {
    sid       = "TfLockRead"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = ["arn:aws:dynamodb:${var.aws_region}:*:table/vantra-terraform-locks"]
  }
  statement {
    sid       = "WhoAmI"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "jenkins_pipeline" {
  name   = "jenkins-pipeline-permissions"
  role   = aws_iam_role.jenkins_role.name
  policy = data.aws_iam_policy_document.jenkins_pipeline.json
}

resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name = "vantra-jenkins-instance-profile"
  role = aws_iam_role.jenkins_role.name
}
