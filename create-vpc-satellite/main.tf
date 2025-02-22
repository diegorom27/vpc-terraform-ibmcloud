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
    generation = 2
}
##############################################################################
#Locals
##############################################################################
locals {
  subnets_map = { for s in var.subnets : s.name => s }
}

##############################################################################
# Resource Group
##############################################################################

data "ibm_resource_group" "cluster-rg" {
  name = var.resource_group
}
##############################################################################
# Satellite
##############################################################################
locals {
  location_zones = [for subnet in var.subnets : subnet.zone]
}
resource "ibm_satellite_location" "satellite-location-demo" {
  location          = "satellite-location-demo"
  zones             = local.location_zones
  managed_from      = "us-south-1"
  resource_group_id = data.ibm_resource_group.cluster-rg.id
  coreos_enabled   = false
}

data "ibm_satellite_attach_host_script" "script" {
  location          = ibm_satellite_location.satellite-location-demo.location
  host_provider     = "ibm"
  coreos_host      = false

  depends_on = [ ibm_satellite_location.satellite-location-demo ]
}

##############################################################################
# VPC
##############################################################################

resource "ibm_is_vpc" "cluster-vpc" {
  name = "${var.BASENAME}-vpc"
  resource_group = data.ibm_resource_group.cluster-rg.id
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

##############################################################################
# Public Gateway 
##############################################################################

resource "ibm_is_public_gateway" "p-gateway" {
  for_each = {for sub in var.subnets : sub.name => sub }
  name = "${each.value.zone}-gateway"
  vpc  = ibm_is_vpc.cluster-vpc.id
  zone = each.value.zone  
  resource_group = data.ibm_resource_group.cluster-rg.id

  timeouts {
    create = "90m"
  }
  
  depends_on = [ ibm_is_vpc.cluster-vpc ]
}


##############################################################################
# subnet 
##############################################################################

resource "ibm_is_subnet" "subnets" {
  for_each = {for vm in var.subnets : vm.name => vm }
  name                     = each.value.name
  vpc                      = ibm_is_vpc.cluster-vpc.id
  zone                     = each.value.zone
  ipv4_cidr_block          = each.value.cidr
  resource_group = data.ibm_resource_group.cluster-rg.id


  depends_on = [ibm_is_vpc_address_prefix.cluster-address-prefix]
}

resource "ibm_is_subnet_public_gateway_attachment" "public_gateway_attachment" {
  for_each = {for sub in var.subnets : sub.name => sub }
  subnet                = ibm_is_subnet.subnets[each.value.name].id
  public_gateway         = ibm_is_public_gateway.p-gateway[each.value.name].id

  depends_on = [ibm_is_vpc_address_prefix.cluster-address-prefix, ibm_is_subnet.subnets]
}
##############################################################################
# security_group
##############################################################################

resource "ibm_is_security_group" "cluster-sg" {
  name = "${var.BASENAME}-sg1"
  vpc  = ibm_is_vpc.cluster-vpc.id

  depends_on = [ ibm_is_vpc.cluster-vpc ]
}

resource "ibm_is_security_group_rule" "tcp_rule" {
  group      = ibm_is_security_group.cluster-sg.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"
  depends_on = [ ibm_is_security_group.cluster-sg ]
  tcp {
  }
}
resource "ibm_is_security_group_rule" "udp_rule" {
  group      = ibm_is_security_group.cluster-sg.id
  direction  = "inbound"
  remote     = "0.0.0.0/0"
  depends_on = [ ibm_is_security_group.cluster-sg ]
  udp {
  }
}
resource "ibm_is_security_group_rule" "icmp_rule" {
  group     = ibm_is_security_group.cluster-sg.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  depends_on = [ ibm_is_security_group.cluster-sg ]
  icmp {
  }
}
resource "ibm_is_security_group_rule" "cluster_egress_rule_all" {
  group     = ibm_is_security_group.cluster-sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
  depends_on = [ ibm_is_security_group.cluster-sg ]
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
  vpc     = ibm_is_vpc.cluster-vpc.id
  zone    = local.subnets_map[each.value.subnetIndex].zone
  keys    = [ibm_is_ssh_key.ssh_key.id]
  image   = var.image-coreos
  profile = var.ENABLE_HIGH_PERFORMANCE ?each.value.hProfile:each.value.lProfile
  user_data =  file(data.ibm_satellite_attach_host_script.script.script_path)
  resource_group = data.ibm_resource_group.cluster-rg.id

  primary_network_interface {
      subnet          = ibm_is_subnet.subnets[each.value.subnetIndex].id
      security_groups = [ibm_is_security_group.cluster-sg.id]
  }
  depends_on = [ data.ibm_satellite_attach_host_script.script ]
}
resource "ibm_is_instance_volume_attachment" "control-vol-attach" {
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

resource "ibm_is_instance" "worker" {
  for_each = { for vm in var.worker : vm.name => vm }
  name    =  each.value.name
  vpc     = ibm_is_vpc.cluster-vpc.id
  zone    = local.subnets_map[each.value.subnetIndex].zone
  keys    = [ibm_is_ssh_key.ssh_key.id]
  image   = var.image-coreos
  profile = var.ENABLE_HIGH_PERFORMANCE ?each.value.hProfile:each.value.lProfile
  user_data =  file(data.ibm_satellite_attach_host_script.script.script_path)
  resource_group = data.ibm_resource_group.cluster-rg.id


  primary_network_interface {
      subnet          = ibm_is_subnet.subnets[each.value.subnetIndex].id
      security_groups = [ibm_is_security_group.cluster-sg.id]
  }
  depends_on = [ data.ibm_satellite_attach_host_script.script ]
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
##############################################################################
# Asignacion de hosts*(En caso de no querer usar scripts)
# Esta forma permitiria asignar los coreos en schematics
# Schematics no permite archivos .ign
##############################################################################

#resource "ibm_satellite_host" "assign_host" {
#  for_each = { for vm in var.control_plane : vm.name => vm }
#
#  location      = ibm_satellite_location.satellite-location-demo.id
#
#  host_id       = ibm_is_instance.control_plane[each.value.name].id
#  labels        = ["env:prod"]
#  zone          = local.subnets_map[each.value.subnetIndex].zone 
#  host_provider = "ibm"
#  #depends_on = [time_sleep.wait_30_min]
#    depends_on = [ibm_is_instance.control_plane]
#}

##############################################################################
# Acceso sin bastion
##############################################################################

#resource "ibm_is_floating_ip" "fip_worker" {
#  for_each = { for vm in var.worker : vm.name => vm }
#  name   = "${var.BASENAME}-fip-${each.value.name}"
#  target = ibm_is_instance.worker["${each.value.name}"].primary_network_interface[0].id
#  resource_group = data.ibm_resource_group.cluster-rg.id
#}


#resource "ibm_is_floating_ip" "fip_control_plane" {
#  for_each = { for vm in var.control_plane : vm.name => vm }
#  name   = "${var.BASENAME}-fip-${each.value.name}"
#  target = ibm_is_instance.control_plane["${each.value.name}"].primary_network_interface[0].id
#  resource_group = data.ibm_resource_group.cluster-rg.id
#}

##############################################################################
# Bastion
##############################################################################

resource "ibm_is_instance" "bastion" {
  name    = "bastion"
  vpc     = ibm_is_vpc.cluster-vpc.id
  zone    = var.subnets[0].zone
  keys    = [ibm_is_ssh_key.ssh_key.id]
  image   = var.image-windows
  profile = var.bastion-profile
  resource_group = data.ibm_resource_group.cluster-rg.id

  primary_network_interface {
      subnet          = ibm_is_subnet.subnets[var.subnets[0].name].id
      security_groups = [ibm_is_security_group.cluster-sg.id]
  }
}

resource "ibm_is_floating_ip" "fip_bastion" {
  name   = "bastion-fip"
  target = ibm_is_instance.bastion.primary_network_interface[0].id
  resource_group = data.ibm_resource_group.cluster-rg.id
}

##############################################################################
# Output
##############################################################################

output "fip_bastion" {
  value = ibm_is_floating_ip.fip_bastion.address
}

output "bastion_password_command" {
  value = "ibmcloud is instance-initialization-values ${ibm_is_instance.bastion.id} --private-key '@~/.ssh/id_rsa'"
}