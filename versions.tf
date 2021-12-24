terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.70"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.1"
    }
    template = {
      source  = "hashicorp/template"
      version = ">= 2.1"
    }
  }
  required_version = ">= 0.13"
}
