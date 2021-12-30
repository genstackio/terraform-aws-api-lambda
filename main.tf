module "api" {
  source     = "genstackio/apigateway2-api/aws"
  version    = "0.1.4"
  name       = (null == var.api_name) ? "${var.env}-api-${var.name}" : var.api_name
  lambda_arn = var.lambda_arn
}

resource "aws_cloudfront_origin_access_identity" "oai" {
  count = length(var.static_assets) > 0 ? 1 : 0
}


resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = module.api.dns
    origin_id   = (null == var.api_name) ? "${var.env}-api-${var.name}" : var.api_name

    dynamic custom_header {
      for_each = var.edge_lambdas_variables
      content {
        name  = "x-lambda-var-${replace(lower(custom_header.key), "_", "-")}"
        value = custom_header.value
      }
    }

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  dynamic "logging_config" {
    for_each = (null != var.accesslogs_s3_bucket) ? {a: true} : {}
    content {
      bucket = var.accesslogs_s3_bucket
      prefix = "${var.dns}/"
    }
  }

  dynamic "origin" {
    for_each = {for s in toset(var.static_assets):s.id => s}
    content {
      domain_name = aws_s3_bucket.static_assets[(null != origin.value.bucket_id) ? origin.value.bucket_id : origin.value.id].bucket_regional_domain_name
      origin_id   = origin.value.id
      s3_origin_config {
        origin_access_identity = aws_cloudfront_origin_access_identity.oai[0].cloudfront_access_identity_path
      }
    }
  }
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.env} api ${var.name} distribution"

  aliases = [var.dns]

  default_cache_behavior {
    allowed_methods  = var.allowed_methods
    cached_methods   = var.cached_methods
    target_origin_id = (null == var.api_name) ? "${var.env}-api-${var.name}" : var.api_name

    forwarded_values {
      query_string = null == var.forward_query_string ? true : var.forward_query_string
      headers      = var.forwarded_headers
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 86400
    compress               = true

    dynamic "lambda_function_association" {
      for_each = {for i,l in var.edge_lambdas: "lambda-${i}" => l}
      content {
        event_type   = lambda_function_association.value.event_type
        lambda_arn   = lambda_function_association.value.lambda_arn
        include_body = lambda_function_association.value.include_body
      }
    }

    dynamic "function_association" {
      for_each = {for i,l in var.functions: "function-${i}" => l}
      content {
        event_type   = function_association.value.event_type
        function_arn = function_association.value.function_arn
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = {for s in toset(var.static_assets):s.id => s}
    content {
      path_pattern             = ordered_cache_behavior.value.path_pattern
      allowed_methods          = ["GET", "HEAD", "OPTIONS"]
      cached_methods           = ["GET", "HEAD"]
      target_origin_id         = (null != ordered_cache_behavior.value.bucket_id) ? ordered_cache_behavior.value.bucket_id : ordered_cache_behavior.value.id
      viewer_protocol_policy   = "redirect-to-https"
      cache_policy_id          = data.aws_cloudfront_cache_policy.managed_caching_optimized.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.managed_cors_s3_origin.id
      compress                 = true

      dynamic "lambda_function_association" {
        for_each = {for i,l in var.static_assets_edge_lambdas: "static-assets-lambda-${i}" => l}
        content {
          event_type   = lambda_function_association.value.event_type
          lambda_arn   = lambda_function_association.value.lambda_arn
          include_body = lambda_function_association.value.include_body
        }
      }

      dynamic "function_association" {
        for_each = {for i,l in var.static_assets_functions: "static-assets-function-${i}" => l}
        content {
          event_type   = function_association.value.event_type
          function_arn = function_association.value.function_arn
        }
      }
    }
  }

  price_class = var.price_class

  restrictions {
    geo_restriction {
      restriction_type = length(var.geolocations) == 0 ? "none" : "whitelist"
      locations        = length(var.geolocations) == 0 ? null : var.geolocations
    }
  }

  tags = {
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

resource "aws_route53_record" "cdn" {
  zone_id = var.dns_zone
  name    = var.dns
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = var.dns
  validation_method = "DNS"
  provider          = aws.acm

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  name    = element(tolist(aws_acm_certificate.cert.domain_validation_options), 0).resource_record_name
  type    = element(tolist(aws_acm_certificate.cert.domain_validation_options), 0).resource_record_type
  zone_id = var.dns_zone
  records = [element(tolist(aws_acm_certificate.cert.domain_validation_options), 0).resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.acm
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}


resource "aws_s3_bucket" "static_assets" {
  for_each = {for s in toset(var.static_assets):s.id => s if null == s.bucket_id}
  bucket   = lookup(each.value, "bucket_name")
  acl      = "private"
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["POST", "GET", "PUT", "DELETE"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_policy" "static_assets" {
  for_each = {for s in toset(var.static_assets):s.id => s if null == s.bucket_id}
  bucket   = aws_s3_bucket.static_assets[each.key].id
  policy   = data.aws_iam_policy_document.s3_website_policy[each.key].json
}
