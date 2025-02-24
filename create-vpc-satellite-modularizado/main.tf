##############################################################################
# Terraform Providers
##############################################################################
terraform {
  required_providers {
    ibm = {
      source = "ibm-cloud/ibm"
      version = ">=1.19.0"
    }
  }
}
provider ibm {
    alias  = "primary"
    region = var.ibm_region
    max_retries = 20
    generation = 2
}
##############################################################################
#Locals
##############################################################################
locals {
  subnets_map = { for s in var.subnets : s.name => s }
}
locals {
  location_zones = [for subnet in var.subnets : subnet.zone]
}
##############################################################################
# Data Sources
##############################################################################
data "ibm_resource_group" "cluster-rg" {
  name = var.resource_group
}
##############################################################################
# Modules
##############################################################################

module "satellite" {
    source = "./modules/satellite"
    location_zones = local.location_zones
    datacenter-satellite = var.datacenter-satellite
    resource_group = data.ibm_resource_group.cluster-rg.id   
}

module "vpc" {
    source = "./modules/vpc"
    vpc_name = "${var.BASENAME}-vpc"
    resource_group = data.ibm_resource_group.cluster-rg.id
    subnets = var.subnets
}

module "subnets" {
    source = "./modules/subnets"
    subnets = var.subnets
    vpc_id = module.vpc.vpc_id
    resource_group = data.ibm_resource_group.cluster-rg.id
}

module "security_groups" {
    source = "./modules/security_groups"
    vpc_id = module.vpc.vpc_id
    resource_group = data.ibm_resource_group.cluster-rg.id
    sg_name = "${var.BASENAME}-sg"
}
module "instances" {
    source = "./modules/instances"
    resource_group = data.ibm_resource_group.cluster-rg.id
    vpc_id = module.vpc.vpc_id
    worker = var.worker
    control_plane = var.control_plane
    subnets_map = local.subnets_map
    image-coreos = var.image-coreos
    image-windows = var.image-windows
    script_path = module.satellite.script_path
    ssh_key_name = "${var.BASENAME}-ssh-key"
    ENABLE_HIGH_PERFORMANCE = var.ENABLE_HIGH_PERFORMANCE
    ibm_subnets_map = { for s in module.subnets.subnets_result : s.name => s.id }
    sg_id = module.security_groups.sg_id
    subnets = var.subnets
    bastion-profile = var.bastion-profile
}

output "fip_bastion" {
  value = "Ip bastion: ${module.instances.fip_bastion}"
}

output "bastion_password_command" {
  value = "extract password command: ${module.instances.bastion_password_command}"
}