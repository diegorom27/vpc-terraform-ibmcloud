terraform {
  required_providers {
    ibm = {
      source = "ibm-cloud/ibm"
    }
  }
}

resource "ibm_is_vpc" "cluster-vpc" {
  name = var.vpc_name
  resource_group = var.resource_group
  address_prefix_management = "manual"

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

resource "ibm_is_vpc_address_prefix" "cluster-address-prefix" {
  for_each = {for vm in var.subnets : vm.name => vm }
  name = "address-prefix-${each.value.zone}"
  zone = each.value.zone
  vpc  = ibm_is_vpc.cluster-vpc.id
  cidr = each.value.prefix

  depends_on = [ ibm_is_vpc.cluster-vpc ]
}