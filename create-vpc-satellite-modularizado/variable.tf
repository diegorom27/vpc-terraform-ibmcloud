variable ibm_region {
    description = "IBM Cloud region where all resources will be deployed"
    type        = string
    default = "us-south"
    validation  {
      error_message = "Must use an IBM Cloud region. Use `ibmcloud regions` with the IBM Cloud CLI to see valid regions."
      condition     = can(
        contains([
          "au-syd",
          "jp-tok",
          "eu-de",
          "eu-gb",
          "us-south",
          "us-east"
        ], var.ibm_region)
      )
    }
}

variable "datacenter-satellite" {
    description = "Datacenter to create resources in"
    type        = string
    default     = "dal10"
}
variable "resource_group" {
    description = "Resource group to create resources in"
    type        = string
    default     = "satellite-demo-rg"
}
variable BASENAME {
    type        = string
    default     = "satellite-demo"
  
}
variable datacenter {
    type        = string
    default     = "dal10"
}
variable ENABLE_HIGH_PERFORMANCE {
    type        = bool
    default     = false
}
variable "subnets" {
    description = "List of subnets to create"
    type = list(object({
        name = string,
        cidr = string,
        zone = string,
        prefix = string
    }))
    default = [
      {
        name = "subnet-0",
        cidr = "10.241.0.0/24",
        zone = "us-south-1",
        prefix="10.241.0.0/18"
      },
      {
        name = "subnet-1",
        cidr = "10.241.64.0/24",
        zone = "us-south-2"
        prefix="10.241.64.0/18"
      },
      {
        name = "subnet-2",
        cidr = "10.241.128.0/24",
        zone = "us-south-3"
        prefix="10.241.128.0/18"
      }
    ]
}
variable "image-coreos" {
    description = "CoreOS image ID"
    type        = string
    default     = "r006-1f8aa558-5a97-4e31-a43f-75cc97e0aeae"
}
variable "bastion-profile" {
    description = "Bastion profile"
    type        = string
    default     = "bx2-4x16"
  
}
variable "image-windows" {
    description = "Windows image ID"
    type        = string
    default     = "r006-1881f528-9ece-4131-abc9-144c16fa0b7f"
}
variable "control_plane" {
    description = "List of vm for control plane"
    type = list(object({
        name = string,
        disksSize = number,
        hProfile= string,
        lProfile= string,
        imageId= string ,
        subnetIndex = string
    }))
    default = [
        {
          name = "control-plane-0",
          disksSize    = 100,
          hProfile = "bx2-4x16",
          lProfile = "bx2-4x16",
          imageId = "none",
          subnetIndex = "subnet-0"
        },{
          name = "control-plane-1",
          disksSize    = 100,
          hProfile = "bx2-4x16",
          lProfile = "bx2-4x16",
          imageId = "none",
          subnetIndex = "subnet-1"
        },{
          name = "control-plane-2",
          disksSize    = 100,
          hProfile = "bx2-4x16",
          lProfile = "bx2-4x16",
          imageId = "none",
          subnetIndex = "subnet-2"
        }
    ]
}

variable worker {
    description = "List of vm for control plane"
    type = list(object({
        name = string,
        disksSize = number,
        hProfile= string,
        lProfile= string,
        imageId= string ,
        subnetIndex = string
    }))
    default = [
        {
          name = "worker-0",
          disksSize    = 100,
          hProfile = "bx2-4x16",
          lProfile = "bx2-4x16",
          imageId = "none",
          subnetIndex = "subnet-0"
        },{
          name = "worker-1",
          disksSize    = 100,
          hProfile = "bx2-4x16",
          lProfile = "bx2-4x16",
          imageId = "none",
          subnetIndex = "subnet-1"
        },{
          name = "worker-2",
          disksSize    = 100,
          hProfile = "bx2-4x16",
          lProfile = "bx2-4x16",
          imageId = "none",
          subnetIndex = "subnet-2"
        }
    ]
}