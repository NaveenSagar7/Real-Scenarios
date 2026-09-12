# IAM role assumed by the meter-reading-service pod via IRSA (IAM Roles for Service
# Accounts). Grants least-privilege access to the raw-reads S3 bucket and the
# normalized-reads DynamoDB table only.

data "aws_iam_policy_document" "meter_reading_service_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      # NOTE: this was set up against the original service-account plan
      # ("vantra-meter" namespace) before the namespace was finalized.
      values = ["system:serviceaccount:vantra-meter:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "meter_reading_service" {
  name               = "${var.project}-meter-reading-service-irsa"
  assume_role_policy = data.aws_iam_policy_document.meter_reading_service_trust.json
}

data "aws_iam_policy_document" "meter_reading_service_permissions" {
  statement {
    sid    = "RawReadsBucketAccess"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
    ]
    resources = ["${aws_s3_bucket.meter_reads.arn}/*"]
  }

  statement {
    sid       = "NormalizedReadsTableAccess"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem"]
    resources = [aws_dynamodb_table.meter_reads.arn]
  }
}

resource "aws_iam_policy" "meter_reading_service" {
  name   = "${var.project}-meter-reading-service-policy"
  policy = data.aws_iam_policy_document.meter_reading_service_permissions.json
}

resource "aws_iam_role_policy_attachment" "meter_reading_service" {
  role       = aws_iam_role.meter_reading_service.name
  policy_arn = aws_iam_policy.meter_reading_service.arn
}

output "meter_reading_service_role_arn" {
  value = aws_iam_role.meter_reading_service.arn
}
