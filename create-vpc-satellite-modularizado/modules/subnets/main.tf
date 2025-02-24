terraform {
  required_providers {
    ibm = {
      source = "ibm-cloud/ibm"
    }
  }
}

##############################################################################
# Prefiexes
##############################################################################

resource "ibm_is_vpc_address_prefix" "cluster-address-prefix" {
  for_each = {for vm in var.subnets : vm.name => vm }
  name = "address-prefix-${each.value.zone}"
  zone = each.value.zone
  vpc  = var.vpc_id
  cidr = each.value.prefix
}

##############################################################################
# Public Gateway 
##############################################################################

resource "ibm_is_public_gateway" "p-gateway" {
  for_each = {for sub in var.subnets : sub.name => sub }
  name = "${each.value.zone}-gateway"
  vpc  = var.vpc_id
  zone = each.value.zone  
  resource_group = var.resource_group
  timeouts {
    create = "90m"
  }
  depends_on = [ ibm_is_vpc_address_prefix.cluster-address-prefix ]
}


##############################################################################
# subnet 
##############################################################################

resource "ibm_is_subnet" "subnets" {
  for_each = {for vm in var.subnets : vm.name => vm }
  name                     = each.value.name
  vpc                      = var.vpc_id
  zone                     = each.value.zone
  ipv4_cidr_block          = each.value.cidr
  resource_group = var.resource_group
  
  depends_on = [ ibm_is_vpc_address_prefix.cluster-address-prefix ]
}

##############################################################################
# Public Gateway Attachment 
##############################################################################

resource "ibm_is_subnet_public_gateway_attachment" "public_gateway_attachment" {
  for_each = {for sub in var.subnets : sub.name => sub }
  subnet                = ibm_is_subnet.subnets[each.value.name].id
  public_gateway         = ibm_is_public_gateway.p-gateway[each.value.name].id
}