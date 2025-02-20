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

import {
  for_each = { for instance in data.ibm_is_instances.ds_instances.instances : instance.id => instance }
  to       = ibm_is_instance.vsi[each.key]
  id       = each.key
}

locals {
  machines_map = { for m in var.MACHINES : m.name => { hProfile = m.hProfile, lProfile = m.lProfile } }
  instances_map = {
    for instance in data.ibm_is_instances.ds_instances.instances :
    instance.id =>{
      name = instance.name
      id = instance.id
      image = instance.image
      vpc   = instance.vpc
      zone  = instance.zone
      subnet = [for ni in instance.primary_network_interface : ni.subnet][0]
      sec_groups = flatten([for ni in instance.primary_network_interface : ni.security_groups])
      hProfile   = lookup(local.machines_map, instance.name, null) != null ? local.machines_map[instance.name].hProfile : instance.profile
      lProfile   = lookup(local.machines_map, instance.name, null) != null ? local.machines_map[instance.name].lProfile : instance.profile
    }     
  }
}
output "instances_map" {
  value = keys(local.instances_map)
  
}
##############################################################################
# Virtual Server Instance
##############################################################################

resource "ibm_is_instance" "vsi" { 
  #depends_on = [ null_resource.import_instances ]
  for_each = { for vm in local.instances_map : vm.id => vm }
  name    =  each.value.name
  profile = var.ENABLE_HIGH_PERFORMANCE ? each.value.hProfile : each.value.lProfile
  image   = each.value.image
  vpc = each.value.vpc
  zone = each.value.zone

  
  primary_network_interface {
    subnet = each.value.subnet
    security_groups = each.value.sec_groups
  }
  
  lifecycle {
    ignore_changes = [
      primary_network_interface,
      image,
      keys,
      vpc,
      zone,
      name,
      boot_volume,
      auto_delete_volume,
      network_interfaces,
      resource_group,
      user_data,
      volumes
    ]
  }
}