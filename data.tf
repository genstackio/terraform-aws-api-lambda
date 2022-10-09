# Managed origin request policy
data "aws_cloudfront_origin_request_policy" "managed_cors_s3_origin" {
  name = "Managed-CORS-S3Origin"
}
data "aws_cloudfront_origin_request_policy" "managed_cors_custom_origin" {
  name = "Managed-CORS-CustomOrigin"
}
data "aws_cloudfront_origin_request_policy" "managed_all_viewer" {
  name = "Managed-AllViewer"
}

# Managed cache policy
data "aws_cloudfront_cache_policy" "managed_caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_iam_policy_document" "s3_website_policy" {
  for_each = (true == var.no_static_assets_bucket_policy) ? {} : { for s in toset(var.static_assets) : s.id => s if null == s.bucket_id }
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
data "aws_iam_policy_document" "s3_website_policy_unmanaged" {
  for_each = (true == var.no_static_assets_bucket_policy) ? {} : { for s in toset(var.unmanaged_static_assets) : s.id => s if null == s.bucket_id }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.unmanaged_static_assets[each.key].arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai[0].iam_arn]
    }
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [data.aws_s3_bucket.unmanaged_static_assets[each.key].arn]
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai[0].iam_arn]
    }
  }
}
