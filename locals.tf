locals {
  functions = {for k, v in var.functions: lookup(v, "name", "function-${k}") => v if lookup(v, "name", "function-${k}") != null}
}
