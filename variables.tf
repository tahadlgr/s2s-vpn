variable "aws_region" {
  type        = string
  description = "aws region to deploy resources in"
  default     = "eu-central-1"
}

variable "environment" {
  type        = string
  description = "environment name that will be prefixed to resource names"
}

variable "vpc_cidr" {
  type    = string
  default = "10.192.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.192.10.0/23"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.192.20.0/23"
}

variable "enable_vpn" {
  type        = bool
  description = "Enable Site-to-Site VPN between our AWS VPC and customer's on-prem infrastructure"
  default     = false
}

variable "vpn_subnet_cidr" {
  type        = string
  description = "cidr provided by the customer that will be routed through site-to-site vpn"
  default     = "10.192.30.0/23"
}

variable "vpn_customer_gw_ip" {
  type        = string
  description = "Peer IP on the customer side of the Site-to-Site VPN"
  default     = ""
}

variable "customer_network_cidr" {
  type        = string
  description = "customer network cidr provided by the customer that will be accessed through site-to-site vpn by our services"
  default     = ""
}

variable "vpn_preshared_key_1" {
  type      = string
  sensitive = true
  default   = ""
}

variable "vpn_preshared_key_2" {
  type      = string
  sensitive = true
  default   = ""
}

variable "s2s_vpn_check_slack_webhook_url" {
  type        = string
  description = "Webhook url of Slack channel for s2s vpn check alerts."
  sensitive   = true
  default     = ""
}
