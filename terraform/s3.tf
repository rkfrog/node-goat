resource "aws_s3_bucket" "node_goat_uploads" {
  bucket = "node-goat-${var.environment}-user-uploads"
}

resource "aws_s3_bucket_public_access_block" "node_goat_uploads" {
  bucket                  = aws_s3_bucket.node_goat_uploads.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "node_goat_uploads_acl" {
  bucket = aws_s3_bucket.node_goat_uploads.id
  acl    = "public-read-write"
}

resource "aws_s3_bucket_versioning" "node_goat_uploads" {
  bucket = aws_s3_bucket.node_goat_uploads.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket" "node_goat_logs" {
  bucket = "node-goat-${var.environment}-logs"
}
