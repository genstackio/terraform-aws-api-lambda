# AWS API Lambda Terraform module

Terraform module which creates API Gateway v2 linked to a Lambda on AWS.

## Usage

```hcl
module "api-lambda" {
  source     = "genstackio/api-lambda/aws"

  name       = "my-api-name"
  env        = "prod"
  lambda_arn = "arn:the-arn-of-the-lambda-here"
  dns        = "mydomain.com"
  dns_zone   = "id-of-the-route53-zone"
}
```
