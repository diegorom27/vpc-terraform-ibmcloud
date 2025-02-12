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

resource "ibm_resource_group" "example-rg" {
  name = "${var.BASENAME}-resource-group"
}

##############################################################################
# VPC
##############################################################################

resource "ibm_is_vpc" "example-vpc" {
  name = "${var.BASENAME}-vpc"
  resource_group = ibm_resource_group.example-rg.id
}

resource "ibm_is_vpc_address_prefix" "example-address-prefix" {
  name = "${var.BASENAME}-address-prefix"
  zone = var.ZONE
  vpc  = ibm_is_vpc.example-vpc.id
  cidr = "10.0.0.0/24"
}

##############################################################################
# Public Gateway 
##############################################################################

resource "ibm_is_public_gateway" "example-gateway" {
  name = "${var.BASENAME}-gateway"
  vpc  = ibm_is_vpc.example-vpc.id
  zone = var.ZONE

  //User can configure timeouts
  timeouts {
    create = "90m"
  }
}
##############################################################################
# subnet 
##############################################################################

resource "ibm_is_subnet" "subnets" {
  for_each = {for vm in var.machines : vm.name => vm }
  name                     = each.value.name
  vpc                      = ibm_is_vpc.example-vpc.id
  zone                     = var.ZONE
  ipv4_cidr_block          = each.value.cidr
  resource_group = ibm_resource_group.example-rg.id
}

##############################################################################
# security_group
##############################################################################

resource "ibm_is_security_group" "example-sg" {
  name = "${var.BASENAME}-sg1"
  vpc  = ibm_is_vpc.example-vpc.id
}

# allow all incoming network traffic on port 22
resource "ibm_is_security_group_rule" "ingress_ssh_all" {
  group     = ibm_is_security_group.example-sg.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}
##############################################################################
# Image
##############################################################################

data "ibm_is_images" "available_images" {
  visibility = "public"
  status     = "available"
}

locals {
  windows_server_images = [
    for image in data.ibm_is_images.available_images.images :
    image if length(regexall(".*windows-server-2016.*", image.name)) > 0
  ]
}

##############################################################################
# Gestión de Claves SSH
##############################################################################

# Cargar la clave pública SSH en IBM Cloud
resource "ibm_is_ssh_key" "ssh_key" {
  name       = "${var.BASENAME}-ssh-key"
  public_key = file("${path.module}/id_rsa.pub")
}
##############################################################################
# Virtual Server Instance
##############################################################################

resource "ibm_is_instance" "vsi" {
  for_each = { for vm in var.machines : vm.name => vm }
  name    =  each.value.name
  vpc     = ibm_is_vpc.example-vpc.id
  zone    = var.ZONE
  keys    = [ibm_is_ssh_key.ssh_key.id]
  image   = local.windows_server_images[0].id
  profile = var.ENABLE_HIGH_PERFORMANCE ?each.value.hProfile:each.value.lProfile

  primary_network_interface {
      subnet          = ibm_is_subnet.subnets[each.value.namel.subnetIndex].id
      security_groups = [ibm_is_security_group.example-sg.id]
  }
}
resource "ibm_is_instance_volume_attachment" "example-vol-att-1" {
  for_each = { for vm in var.machines : vm.name => vm }
  
  instance = ibm_is_instance.vsi[each.key].id
  name     = "${each.value.name}-vol-attachment"
  delete_volume_on_instance_delete = true
  capacity = each.value.disksSize
  profile                            = "general-purpose"
  delete_volume_on_attachment_delete = true
  volume_name                        = "${each.value.name}-vol-1"

  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }
}
resource "ibm_is_floating_ip" "fip1" {
  name   = "${var.BASENAME}-fip1"
  target = ibm_is_instance.vsi[0].primary_network_interface[0].id
}
