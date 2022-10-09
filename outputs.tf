output "endpoint" {
  value = "https://${var.dns}"
}
output "internal_endpoint" {
  value = module.api.endpoint
}
output "static_assets_buckets" {
  value = { for i, b in aws_s3_bucket.static_assets : i => {
    name = b.bucket
    arn  = b.arn
  } }
}
output "cloudfront_id" {
  value = aws_cloudfront_distribution.cdn.id
}
output "cloudfront_arn" {
  value = aws_cloudfront_distribution.cdn.arn
}
output "cloudfront_origin_access_identity_iam_arn" {
  value = length(aws_cloudfront_origin_access_identity) > 0 ? aws_cloudfront_origin_access_identity[0].iam_arn : null
}