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

resource "null_resource" "fetch_state" {
  provisioner "local-exec" {
    command ="ibmcloud schematics state list --id us-south.workspace.vpc-test.643cd01d --output json | jq '[.[] | select(.resources != null) | .resources[] | {resource_type, resource_name, resource_id, resource_group_name}]' > state.json"
  }
}
data "ibm_is_instances" "ds_instances" {
  resource_group = data.ibm_resource_group.group.id
}

data "local_file" "terraform_state_file" {
  depends_on = [null_resource.fetch_state]
  filename   = "${path.module}/state.json"
}

locals {  
  terraform_state = jsondecode(data.local_file.terraform_state_file.content)

  ibm_instances_map = { for res in local.terraform_state :
    res.resource_id => res
    if res.resource_type == "ibm_is_instance" && res.resource_group_name == data.ibm_resource_group.group.name
  }
  unmanaged_instances_map = { for instance in data.ibm_is_instances.ds_instances.instances :
    instance.id => instance if lookup(local.ibm_instances_map, instance.id, null) == null
  }
}

output "managed_instances" {
  value = keys(local.ibm_instances_map)
}
#import {
#  for_each = local.unmanaged_instances_map
#  to = ibm_is_instance.vsi[each.key]
#  id = each.key
#}

resource "null_resource" "delayed_import" {
  depends_on = [data.local_file.terraform_state_file]

  provisioner "local-exec" {
    command = <<EOT
      for id in ${join(" ", keys(local.unmanaged_instances_map))}; do
        terraform import ibm_is_instance.vsi[$id] $id
      done
    EOT
  }
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
  depends_on = [null_resource.delayed_import] 
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