terraform {
  required_version = ">= 1.6"
  required_providers {
    aws      = { source = "hashicorp/aws", version = "~> 5.0" }
    template = { source = "hashicorp/template", version = "~> 2.2" }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.region
}
