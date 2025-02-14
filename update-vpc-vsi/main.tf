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
  instances_map = {
    for instance in data.ibm_is_instances.ds_instances.instances :
    instance.name => {
      id   = instance.id
      image = instance.image
      vpc   = instance.vpc
      zone  = instance.zone
      subnet = [for ni in instance.primary_network_interface : ni.subnet][0]
      sec_groups = flatten([for ni in instance.primary_network_interface : ni.security_groups])
    }
  }
}

resource "null_resource" "import_instance" {
  
  for_each = { for vm in var.MACHINES : vm.name => vm }

  provisioner "local-exec" {
    command = <<EOT
      terraform import ibm_is_instance.vsi["${each.key}"] ${local.instances_map[each.value.name].id}
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}
##############################################################################
# Virtual Server Instance
##############################################################################

resource "ibm_is_instance" "vsi" {
  profile = var.ENABLE_HIGH_PERFORMANCE ?each.value.hProfile:each.value.lProfile
  
  lifecycle {
    ignore_changes = all
  }
}