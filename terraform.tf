terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 4.0.0, < 5.0.0"
      configuration_aliases = [aws.acm]
    }
  }
  experiments = [module_variable_optional_attrs]
}