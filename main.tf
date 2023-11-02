terraform {
  cloud {
    hostname = "app.terraform.io"

    workspaces {
      name = "infrastructure"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.17.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.3.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.26.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 2.1"
    }
  }
  required_version = ">= 1.0.0"
}

provider "aws" {
  region = "eu-central-1"
}

provider "aws" {
  alias  = "main-route53"
  region = "eu-central-1"
  assume_role {
    role_arn = "arn:aws:iam::131605153677:role/route53-role"
  }
}

resource "aws_iam_account_alias" "alias" {
  account_alias = "${var.environment}"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

module "s2s_vpn" {
  count = var.enable_vpn ? 1 : 0

  source = "./modules/s2s_vpn"

  vpc                           = module.network.vpc
  private_routes                = module.network.private_routes
  vpn_routes                    = module.network.vpn_routes
  nat_vpn_network_interface_ids = module.network.nat_vpn_network_interface_ids
  customer_network_cidr         = var.customer_network_cidr
  vpn_subnet_cidr               = var.vpn_subnet_cidr
  preshared_key_1               = var.vpn_preshared_key_1
  preshared_key_2               = var.vpn_preshared_key_2
  slack_webhook_url             = var.s2s_vpn_check_slack_webhook_url
}
