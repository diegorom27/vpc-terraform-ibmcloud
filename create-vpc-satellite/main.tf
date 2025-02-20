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

data "ibm_resource_group" "example-rg" {
  name = var.resource_group
}
##############################################################################
# Satellite script
##############################################################################


data "local_file" "ignition_config" {
  filename = "${abspath(path.module)}/attachHost-satellite-location-1.ign"
}

##############################################################################
# VPC
##############################################################################

resource "ibm_is_vpc" "example-vpc" {
  name = "${var.BASENAME}-vpc"
  resource_group = data.ibm_resource_group.example-rg.id
}

resource "ibm_is_vpc_address_prefix" "example-address-prefix" {
  for_each = {for vm in var.subnets : vm.name => vm }
  name = "${var.BASENAME}-address-prefix"
  zone = each.value.zone
  vpc  = ibm_is_vpc.example-vpc.id
  cidr = each.value.cidr
}

##############################################################################
# Public Gateway 
##############################################################################

resource "ibm_is_public_gateway" "example-gateway" {
  name = "${var.BASENAME}-gateway"
  vpc  = ibm_is_vpc.example-vpc.id
  zone = "us-east-1"
  resource_group = data.ibm_resource_group.example-rg.id

  timeouts {
    create = "90m"
  }
}
##############################################################################
# subnet 
##############################################################################

resource "ibm_is_subnet" "subnets" {
  for_each = {for vm in var.subnets : vm.name => vm }
  name                     = each.value.name
  vpc                      = ibm_is_vpc.example-vpc.id
  zone                     = each.value.zone
  ipv4_cidr_block          = each.value.cidr
  resource_group = data.ibm_resource_group.example-rg.id
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
resource "ibm_is_security_group_rule" "tcp_rule" {
  group      = ibm_is_security_group.example-sg.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"
  tcp {
  }
}
resource "ibm_is_security_group_rule" "udp_rule" {
  group      = ibm_is_security_group.example-sg.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"
  udp {
  }
}
resource "ibm_is_security_group_rule" "icmp_rule" {
  group     = ibm_is_security_group.example-sg.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  icmp {
  }
}
resource "ibm_is_security_group_rule" "egress_rule_all" {
  group     = ibm_is_security_group.example-sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
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

resource "ibm_is_instance" "control_plane" {
  for_each = { for vm in var.control_plane : vm.name => vm }
  name    =  each.value.name
  vpc     = ibm_is_vpc.example-vpc.id
  zone    = var.subnets[each.value.subnetIndex].zone
  keys    = [ibm_is_ssh_key.ssh_key.id]
  image   = var.image-coreos
  profile = var.ENABLE_HIGH_PERFORMANCE ?each.value.hProfile:each.value.lProfile
  user_data = data.local_file.ignition_config.content
  resource_group = data.ibm_resource_group.example-rg.id

  primary_network_interface {
      subnet          = ibm_is_subnet.subnets[each.value.subnetIndex].id
      security_groups = [ibm_is_security_group.example-sg.id]
  }
}
resource "ibm_is_instance_volume_attachment" "example-vol-att-1" {
  for_each = { for vm in var.control_plane : vm.name => vm }
  
  instance = ibm_is_instance.control_plane[each.key].id
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

resource "ibm_is_floating_ip" "fip_control_plane" {
  for_each = { for vm in var.control_plane : vm.name => vm }
  name   = "${var.BASENAME}-fip-${each.value.name}"
  target = ibm_is_instance.control_plane["${each.value.name}"].primary_network_interface[0].id
  resource_group = data.ibm_resource_group.example-rg.id
}

resource "ibm_is_instance" "worker" {
  for_each = { for vm in var.worker : vm.name => vm }
  name    =  each.value.name
  vpc     = ibm_is_vpc.example-vpc.id
  zone    = var.subnets[each.value.subnetIndex].zone
  keys    = [ibm_is_ssh_key.ssh_key.id]
  image   = var.image-coreos
  profile = var.ENABLE_HIGH_PERFORMANCE ?each.value.hProfile:each.value.lProfile
  user_data = data.local_file.ignition_config.content
  resource_group = data.ibm_resource_group.example-rg.id


  primary_network_interface {
      subnet          = ibm_is_subnet.subnets[each.value.subnetIndex].id
      security_groups = [ibm_is_security_group.example-sg.id]
  }
}
resource "ibm_is_instance_volume_attachment" "worker-vol-attach" {
  for_each = { for vm in var.worker : vm.name => vm }
  
  instance = ibm_is_instance.worker[each.key].id
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

resource "ibm_is_floating_ip" "fip_worker" {
  for_each = { for vm in var.control_plane : vm.name => vm }
  name   = "${var.BASENAME}-fip-${each.value.name}"
  target = ibm_is_instance.worker["${each.value.name}"].primary_network_interface[0].id
  resource_group = data.ibm_resource_group.example-rg.id
}