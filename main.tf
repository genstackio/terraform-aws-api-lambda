module "api" {
  source     = "genstackio/apigateway2-api/aws"
  version    = "0.2.0"
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

    dynamic "custom_header" {
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
    for_each = (null != var.accesslogs_s3_bucket) ? { a : true } : {}
    content {
      bucket = var.accesslogs_s3_bucket
      prefix = "${var.dns}/"
    }
  }

  dynamic "origin" {
    for_each = { for s in toset(var.static_assets) : s.id => s }
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
    allowed_methods            = var.allowed_methods
    cached_methods             = var.cached_methods
    target_origin_id           = (null == var.api_name) ? "${var.env}-api-${var.name}" : var.api_name
    viewer_protocol_policy     = "redirect-to-https"
    cache_policy_id            = (null == var.cache_policy) ? aws_cloudfront_cache_policy.cache[0].id : var.cache_policy
    origin_request_policy_id   = (null == var.origin_request_policy) ? data.aws_cloudfront_origin_request_policy.managed_all_viewer.id : var.origin_request_policy
    response_headers_policy_id = (null == var.response_headers_policy) ? aws_cloudfront_response_headers_policy.custom_cors_with_preflight_and_securityheaders[0].id : var.response_headers_policy
    compress                   = var.compress

    dynamic "lambda_function_association" {
      for_each = { for i, l in var.edge_lambdas : "lambda-${i}" => l }
      content {
        event_type   = lambda_function_association.value.event_type
        lambda_arn   = lambda_function_association.value.lambda_arn
        include_body = lambda_function_association.value.include_body
      }
    }

    dynamic "function_association" {
      for_each = { for i, l in var.functions : "function-${i}" => l }
      content {
        event_type   = function_association.value.event_type
        function_arn = function_association.value.function_arn
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = { for s in toset(var.static_assets) : s.id => s }
    content {
      path_pattern               = ordered_cache_behavior.value.path_pattern
      allowed_methods            = ["GET", "HEAD", "OPTIONS"]
      cached_methods             = ["GET", "HEAD"]
      target_origin_id           = (null != ordered_cache_behavior.value.bucket_id) ? ordered_cache_behavior.value.bucket_id : ordered_cache_behavior.value.id
      viewer_protocol_policy     = "redirect-to-https"
      cache_policy_id            = data.aws_cloudfront_cache_policy.managed_caching_optimized.id
      origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.managed_cors_s3_origin.id
      response_headers_policy_id = (null == var.response_headers_policy) ? aws_cloudfront_response_headers_policy.custom_cors_with_preflight_and_securityheaders[0].id : var.response_headers_policy
      compress                   = true
      dynamic "lambda_function_association" {
        for_each = { for i, l in var.static_assets_edge_lambdas : "static-assets-lambda-${i}" => l }
        content {
          event_type   = lambda_function_association.value.event_type
          lambda_arn   = lambda_function_association.value.lambda_arn
          include_body = lambda_function_association.value.include_body
        }
      }

      dynamic "function_association" {
        for_each = { for i, l in var.static_assets_functions : "static-assets-function-${i}" => l }
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
  for_each = { for s in toset(var.static_assets) : s.id => s if null == s.bucket_id }
  bucket   = lookup(each.value, "bucket_name")
}

resource "aws_s3_bucket_acl" "static_assets" {
  for_each = { for s in toset(var.static_assets) : s.id => s if null == s.bucket_id }
  bucket   = aws_s3_bucket.static_assets[each.key].id
  acl      = "private"
}

resource "aws_s3_bucket_cors_configuration" "static_assets" {
  for_each = { for s in toset(var.static_assets) : s.id => s if null == s.bucket_id }
  bucket   = aws_s3_bucket.static_assets[each.key].bucket

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["POST", "GET", "PUT", "DELETE"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_policy" "static_assets" {
  for_each = { for s in toset(var.static_assets) : s.id => s if null == s.bucket_id }
  bucket   = aws_s3_bucket.static_assets[each.key].id
  policy   = data.aws_iam_policy_document.s3_website_policy[each.key].json
}



resource "aws_cloudfront_cache_policy" "cache" {
  count = (null == var.cache_policy) ? 1 : 0
  name = "${var.env}-${var.name}-cache-policy"

  min_ttl     = var.min_ttl
  default_ttl = var.default_ttl
  max_ttl     = var.max_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = var.compress
    enable_accept_encoding_gzip   = var.compress

    cookies_config {
      cookie_behavior = (null == var.forward_cookies ? false : var.forward_cookies) ? "all" : "none"
    }
    headers_config {
      header_behavior = length(null == var.forwarded_headers ? [] : var.forwarded_headers) > 0 ? "whitelist" : "none"
      dynamic "headers" {
        for_each = length(null == var.forwarded_headers ? [] : var.forwarded_headers) > 0 ? { x : true } : {}
        content {
          items = null == var.forwarded_headers ? [] : var.forwarded_headers
        }
      }
    }
    query_strings_config {
      query_string_behavior = (null == var.forward_query_string ? true : var.forward_query_string) ? "all" : "none"
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "custom_cors_with_preflight_and_securityheaders" {
  count = (null == var.response_headers_policy) ? 1 : 0
  name = "${var.env}-${var.name}-Custom-CORS-with-preflight-and-SecurityHeadersPolicy"

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "PUT", "POST", "PATCH", "DELETE", "OPTIONS"]
    }

    access_control_allow_origins {
      items = ["*"]
    }

    access_control_expose_headers {
      items = ["*"]
    }

    origin_override = false
  }

  security_headers_config {
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = false
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      override                   = false
    }
    xss_protection {
      mode_block = true
      override   = false
      protection = true
    }
  }

}
