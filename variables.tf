variable "name" {
  type = string
}
variable "env" {
  type = string
}
variable "api_name" {
  type    = string
  default = null
}
variable "lambda_arn" {
  type = string
}
variable "dns" {
  type = string
}
variable "dns_zone" {
  type = string
}
variable "geolocations" {
  type    = list(string)
  default = []
}
variable "price_class" {
  type    = string
  default = "PriceClass_100"
}
variable "forward_query_string" {
  type    = bool
  default = true
}
variable "forward_cookies" {
  type    = bool
  default = false
}
variable "forwarded_headers" {
  type    = list(string)
  default = null
}
variable "allowed_methods" {
  type    = list(string)
  default = ["GET", "POST", "DELETE", "PUT", "PATCH", "HEAD", "OPTIONS"]
}
variable "cached_methods" {
  type    = list(string)
  default = ["GET", "HEAD"]
}
variable "edge_lambdas" {
  type = list(object({
    event_type   = string
    lambda_arn   = string
    include_body = bool
  }))
  default = []
}
variable "edge_lambdas_variables" {
  type    = map(string)
  default = {}
}
variable "static_assets_edge_lambdas" {
  type = list(object({
    event_type   = string
    lambda_arn   = string
    include_body = bool
  }))
  default = []
}
variable "unmanaged_static_assets_edge_lambdas" {
  type = list(object({
    event_type   = string
    lambda_arn   = string
    include_body = bool
  }))
  default = []
}
variable "functions" {
  type = list(object({
    event_type   = string
    function_arn = string
  }))
  default = []
}
variable "no_static_assets_bucket_policy" {
  type    = bool
  default = false
}
variable "static_assets_functions" {
  type = list(object({
    event_type   = string
    function_arn = string
  }))
  default = []
}
variable "unmanaged_static_assets_functions" {
  type = list(object({
    event_type   = string
    function_arn = string
  }))
  default = []
}
variable "static_assets" {
  type = list(object({
    path_pattern = string
    id           = string
    bucket_id    = string
    bucket_name  = string
  }))
  default = []
}
variable "unmanaged_static_assets" {
  type = list(object({
    path_pattern = string
    id           = string
    bucket_id    = string
    bucket_name  = string
  }))
  default = []
}
variable "accesslogs_s3_bucket" {
  type    = string
  default = null
}
variable "min_ttl" {
  type    = number
  default = 0
}
variable "max_ttl" {
  type    = number
  default = 86400
}
variable "default_ttl" {
  type    = number
  default = 0
}
variable "compress" {
  type    = bool
  default = true
}
variable "response_headers_policy" {
  type    = string
  default = null
}
variable "origin_request_policy" {
  type    = string
  default = null
}
variable "cache_policy" {
  type    = string
  default = null
}