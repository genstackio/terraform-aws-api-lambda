locals {
  functions = {for k, v in var.functions: lookup(v, "name", "function-${k}") != null ? lookup(v, "name", "function-${k}") : "function-${k}" => v}
}
