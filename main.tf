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
  ipv4_cidr_block = "10.0.1.0/24"
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

data "ibm_is_image" "centos" {
    name = "ibm-centos-7-6-minimal-amd64-1"
}

##############################################################################
# Gestión de Claves SSH
##############################################################################

# Cargar la clave pública SSH en IBM Cloud
resource "ibm_is_ssh_key" "ssh_key" {
  label      = "terraform-ssh-key" 
  public_key = file("${path.module}/id_rsa.pub")
}
##############################################################################
# Virtual Server Instance
##############################################################################

resource "ibm_is_instance" "vsi1" {
    name    = "${var.BASENAME}-vsi1"
    vpc     = ibm_is_vpc.example-vpc.id
    zone    = var.ZONE
    keys    = [ibm_is_ssh_key.ssh_key.id]
    image   = data.ibm_is_image.centos.id
    profile = "cx2-2x4"

    primary_network_interface {
        subnet          = ibm_is_subnet.subnet1.id
        security_groups = [ibm_is_security_group.sg1.id]
    }
    resource "ibm_is_floating_ip" "fip1" {
        name   = "${local.BASENAME}-fip1"
        target = ibm_is_instance.vsi1.primary_network_interface[0].id
    }
    output "sshcommand" {
    value = "ssh root@${ibm_is_floating_ip.fip1.address}"
    }
 } 