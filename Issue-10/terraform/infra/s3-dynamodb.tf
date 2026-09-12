resource "aws_s3_bucket" "meter_reads" {
  bucket        = "${var.project}-raw-reads-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "meter_reads" {
  bucket                  = aws_s3_bucket.meter_reads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "meter_reads" {
  name         = "${var.project}-normalized-reads"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "meter_id"
  range_key    = "reading_id"

  attribute {
    name = "meter_id"
    type = "S"
  }

  attribute {
    name = "reading_id"
    type = "S"
  }
}

output "meter_bucket_name" {
  value = aws_s3_bucket.meter_reads.bucket
}

output "meter_table_name" {
  value = aws_dynamodb_table.meter_reads.name
}
