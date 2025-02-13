##############################################################################
# Terraform Providers
##############################################################################
terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
      version = ">=1.19.0"
    }
  }
}
##############################################################################
# Provider
##############################################################################
# ibmcloud_api_key = var.ibmcloud_api_key
provider ibm {
    alias  = "primary"
    region = var.ibm_region
    max_retries = 20
}
##############################################################################
# Resource Group
##############################################################################

data "ibm_resource_group" "group" {
  name = var.RESOURCE_GROUP
}

##############################################################################
# Virtual Server Instance list
##############################################################################

data "ibm_is_instances" "ds_instances" {
  resource_group = data.ibm_resource_group.group.id
}

##############################################################################
# Virtual Server Instance
##############################################################################

resource "ibm_is_instance" "vsi" {
  for_each = { for vm in var.MACHINES : vm.name => vm }
  name    =  data.ibm_is_instances.ds_instances[each.value.name]
  profile = var.ENABLE_HIGH_PERFORMANCE ?each.value.hProfile:each.value.lProfile
  image   = data.ibm_is_instances.ds_instances[each.value.name].image
  vpc = data.ibm_is_instances.ds_instances[each.value.name].vpc
  zone = data.ibm_is_instances.ds_instances[each.value.name].zone

  primary_network_interface {
    subnet = data.ibm_is_instances.ds_instances[each.value.name].primary_network_interface.subnet
    security_groups = data.ibm_is_instances.ds_instances[each.value.name].primary_network_interface.security_groups
  }
}