resource "aws_vpn_gateway" "s2s" {
  vpc_id = var.vpc

  tags = {
    Name = "s2s-vpn-gateway"
  }
}

resource "aws_vpn_gateway_route_propagation" "s2s" {
  count = length(var.vpn_routes)

  route_table_id = var.vpn_routes[count.index]
  vpn_gateway_id = aws_vpn_gateway.s2s.id
}

locals {
  # TODO revert setproduct if more than one customer network CIDR is not likely
  #
  # Add necessary routes to private subnets routing tables that routes connections to customer network CIDRs 
  # to VPN NAT instances located in the same Availability Zone (subnet)
  route_product = setproduct([var.customer_network_cidr], [for i in range(2) : [var.nat_vpn_network_interface_ids[i], var.private_routes[i]]])
  # [
  #    [ "AAA.AAA.AAA.AAA/BB", [ "eni-xxxxxx", "rtb-xxxxxx" ] ],
  #    [ "CCC.CCC.CCC.CCC/DD", [ "eni-yyyyyy", "rtb-yyyyyy" ] ],
  #    ...
  # ]

  route_data = [for v in local.route_product : { cidr = v[0], nat_vpn_network_interface_id = v[1][0], route_table_id = v[1][1] }]
  # [
  #    {
  #      cidr = "AAA.AAA.AAA.AAA/BB"
  #      nat_vpn_network_interface_id = "eni-xxxxxx"
  #      route_table_id = "rtb-xxxxxx"
  #    },
  #    {
  #      cidr = "CCC.CCC.CCC.CCC/DD"
  #      nat_vpn_network_interface_id = "eni-yyyyyy"
  #      route_table_id = "rtb-yyyyyy"
  #    },
  #    ...
  # ]
}

resource "aws_route" "vpn_private_routes" {
  count = length(local.route_data)

  route_table_id         = local.route_data[count.index].route_table_id
  destination_cidr_block = local.route_data[count.index].cidr
  network_interface_id   = local.route_data[count.index].nat_vpn_network_interface_id
}

resource "aws_customer_gateway" "s2s" {
  bgp_asn    = 65000
  ip_address = var.customer_gw_ip
  type       = "ipsec.1"

  tags = {
    Name = "s2s-vpn-customer-gateway"
  }
}

resource "aws_vpn_connection" "s2s" {
  vpn_gateway_id           = aws_vpn_gateway.s2s.id
  customer_gateway_id      = aws_customer_gateway.s2s.id
  type                     = "ipsec.1"
  static_routes_only       = true
  local_ipv4_network_cidr  = var.customer_network_cidr
  remote_ipv4_network_cidr = var.vpn_subnet_cidr

  tunnel1_ike_versions                 = ["ikev2"]
  tunnel1_preshared_key                = var.preshared_key_1
  tunnel1_phase1_dh_group_numbers      = [20]
  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-384"]
  tunnel1_phase2_dh_group_numbers      = [20]
  tunnel1_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-384"]
  tunnel1_dpd_timeout_action           = "restart"
  tunnel1_startup_action               = "start"

  tunnel2_ike_versions                 = ["ikev2"]
  tunnel2_preshared_key                = var.preshared_key_2
  tunnel2_phase1_dh_group_numbers      = [20]
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-384"]
  tunnel2_phase2_dh_group_numbers      = [20]
  tunnel2_phase2_encryption_algorithms = ["AES256-GCM-16"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-384"]
  tunnel2_dpd_timeout_action           = "restart"
  tunnel2_startup_action               = "start"

  tags = {
    Name = "s2s-vpn-connection"
  }
}

resource "aws_vpn_connection_route" "customer_cidr" {
  destination_cidr_block = var.customer_network_cidr
  vpn_connection_id      = aws_vpn_connection.s2s.id
}
