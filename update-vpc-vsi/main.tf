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


locals {
  machines_map = { for m in var.MACHINES : m.name => { hProfile = m.hProfile, lProfile = m.lProfile } }
  instances_map = {
    for instance in data.ibm_is_instances.ds_instances.instances :
    instance.id =>{
      name = instance.name
      image = instance.image
      vpc   = instance.vpc
      zone  = instance.zone
      subnet = [for ni in instance.primary_network_interface : ni.subnet][0]
      sec_groups = flatten([for ni in instance.primary_network_interface : ni.security_groups])
      hProfile = local.machines_map[instance.name].hProfile
      lProfile = local.machines_map[instance.name].lProfile
    }     
    if contains([for m in var.MACHINES : m.name], instance.name)
  }
}
import {
  for_each = keys(local.instances_map)
  to = ibm_is_instance.vsi[each.key]
  id = each.key
}

##############################################################################
# Virtual Server Instance
##############################################################################

resource "ibm_is_instance" "vsi" {
  for_each = { for vm in var.MACHINES : vm.name => vm }
  name    =  each.value.name
  profile = var.ENABLE_HIGH_PERFORMANCE ?each.value.hProfile:each.value.lProfile
  image   = local.instances_map[each.value.name].image
  vpc = local.instances_map[each.value.name].vpc
  zone = local.instances_map[each.value.name].zone

  
  primary_network_interface {
    subnet = local.instances_map[each.value.name].subnet
    security_groups = local.instances_map[each.value.name].sec_groups
  }
  
  lifecycle {
    ignore_changes = [
      primary_network_interface,
      image,
      keys,
      vpc,
      zone
    ]
  }
}