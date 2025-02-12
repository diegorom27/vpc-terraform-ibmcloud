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
  zone = "us-south-1"
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

resource "ibm_is_subnet" "subnet1" {
  name                     = "${var.BASENAME}-subnet1"
  vpc                      = ibm_is_vpc.example-vpc.id
  zone                     = var.ZONE
  ipv4_cidr_block = "10.0.0.0/24"
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
    image if length(regex(".*windows-server-2016.*", image.name)) > 0
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

resource "ibm_is_instance" "vsi1" {
  count = length(local.windows_server_images) > 0 ? 1 : 0

  name    = "${var.BASENAME}-vsi1"
  vpc     = ibm_is_vpc.example-vpc.id
  zone    = var.ZONE
  keys    = [ibm_is_ssh_key.ssh_key.id]
  image   = local.windows_server_images[0].id
  profile = "cx2-2x4"

  primary_network_interface {
      subnet          = ibm_is_subnet.subnet1.id
      security_groups = [ibm_is_security_group.example-sg.id]
  }
}
data "ibm_is_instance" "windows-instance" {
  name        = ibm_is_instance.vsi1[0].name
  private_key= file("${path.module}/id_rsa")
}
output "windows_admin_password" {
  value = data.ibm_is_instance.windows_instance.encrypted_password
  sensitive = true
}
resource "ibm_is_instance_volume_attachment" "example-vol-att-1" {
  instance = ibm_is_instance.vsi1[0].id
  name                               = "example-vol-att-1"
  profile                            = "general-purpose"
  capacity                           = "20"
  delete_volume_on_attachment_delete = true
  delete_volume_on_instance_delete   = true
  volume_name                        = "example-vol-1"

  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }
}

resource "ibm_is_floating_ip" "fip1" {
  name   = "${var.BASENAME}-fip1"
  target = ibm_is_instance.vsi1[0].primary_network_interface[0].id
} 