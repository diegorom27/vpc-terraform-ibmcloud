terraform {
  required_providers {
    ibm = {
      source = "ibm-cloud/ibm"
    }
  }
}

##############################################################################
# Gestión de Claves SSH
##############################################################################

# Cargar la clave pública SSH en IBM Cloud
resource "ibm_is_ssh_key" "ssh_key" {
  name       = var.ssh_key_name
  public_key = file("${path.module}/id_rsa.pub")
}

##############################################################################
# Virtual Server Instance
##############################################################################

resource "ibm_is_instance" "control_plane" {
  for_each = { for vm in var.control_plane : vm.name => vm }
  name    =  each.value.name
  vpc     = var.vpc_id
  zone    = var.subnets_map[each.value.subnetIndex].zone
  keys    = [ibm_is_ssh_key.ssh_key.id]
  image   = var.image-coreos
  profile = var.ENABLE_HIGH_PERFORMANCE ?each.value.hProfile:each.value.lProfile
  user_data =  file(var.script_path)
  resource_group = var.resource_group

  primary_network_interface {
      subnet          = var.ibm_subnets_map[each.value.subnetIndex]
      security_groups = [var.sg_id]
  }
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
  vpc     = var.vpc_id
  zone    = var.subnets_map[each.value.subnetIndex].zone
  keys    = [ibm_is_ssh_key.ssh_key.id]
  image   = var.image-coreos
  profile = var.ENABLE_HIGH_PERFORMANCE ?each.value.hProfile:each.value.lProfile
  user_data =  file(var.script_path)
  resource_group = var.resource_group


  primary_network_interface {
      subnet          = var.ibm_subnets_map[each.value.subnetIndex]
      security_groups = [var.sg_id]
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

##############################################################################
# Bastion
##############################################################################

resource "ibm_is_instance" "bastion" {
  name    = "bastion"
  vpc     = var.vpc_id
  zone    = var.subnets[0].zone
  keys    = [ibm_is_ssh_key.ssh_key.id]
  image   = var.image-windows
  profile = var.bastion-profile
  resource_group = var.resource_group

  primary_network_interface {
      subnet          = var.ibm_subnets_map[var.subnets[0].name]
      security_groups = [var.sg_id]
  }
}

resource "ibm_is_floating_ip" "fip_bastion" {
  name   = "bastion-fip"
  target = ibm_is_instance.bastion.primary_network_interface[0].id
  resource_group = var.resource_group
}
