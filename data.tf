# Managed origin request policy
data "aws_cloudfront_origin_request_policy" "managed_cors_s3_origin" {
  name = "Managed-CORS-S3Origin"
}

# Managed cache policy
data "aws_cloudfront_cache_policy" "managed_caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_iam_policy_document" "s3_website_policy" {
  for_each = {for s in toset(var.static_assets):s.id => s}
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static_assets[each.key].arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai[0].iam_arn]
    }
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.static_assets[each.key].arn]
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai[0].iam_arn]
    }
  }
}
