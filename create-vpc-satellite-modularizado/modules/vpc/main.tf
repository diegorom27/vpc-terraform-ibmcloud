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
