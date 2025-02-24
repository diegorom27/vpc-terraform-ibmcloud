terraform {
  required_providers {
    ibm = {
      source = "ibm-cloud/ibm"
    }
  }
}
##############################################################################
# security_group
##############################################################################

resource "ibm_is_security_group" "cluster-sg" {
  name = var.sg_name
  resource_group = var.resource_group
  vpc  = var.vpc_id
}

resource "ibm_is_security_group_rule" "tcp_rule" {
  group      = ibm_is_security_group.cluster-sg.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"
  tcp {
  }
}
resource "ibm_is_security_group_rule" "udp_rule" {
  group      = ibm_is_security_group.cluster-sg.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"
  udp {
  }
}
resource "ibm_is_security_group_rule" "icmp_rule" {
  group     = ibm_is_security_group.cluster-sg.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  icmp {
  }
}
resource "ibm_is_security_group_rule" "cluster_egress_rule_all" {
  group     = ibm_is_security_group.cluster-sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}
