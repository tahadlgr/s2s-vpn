variable "vpc" {
  type = string
}

variable "private_routes" {
  type = list(string)
}

variable "vpn_routes" {
  type = list(string)
}

variable "nat_vpn_network_interface_ids" {
  type = list(string)
}

variable "customer_gw_ip" {
  type = string
}

variable "customer_network_cidr" {
  type = string
}

variable "vpn_subnet_cidr" {
  type = string
}

variable "preshared_key_1" {
  type      = string
  sensitive = true
}

variable "preshared_key_2" {
  type      = string
  sensitive = true
}

variable "slack_webhook_url" {
  type = string
}