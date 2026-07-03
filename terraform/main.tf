resource "aws_s3_bucket" "bucket-images" {
  bucket        = var.bucket_name
  force_destroy = true
  tags = {
    Name = "files"
  }
}
