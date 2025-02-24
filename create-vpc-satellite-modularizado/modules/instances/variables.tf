variable "control_plane" {
    type = list(object({
        name = string,
        disksSize = number,
        hProfile= string,
        lProfile= string,
        imageId= string ,
        subnetIndex = string
    }))
}
variable "worker" {
    type = list(object({
        name = string,
        disksSize = number,
        hProfile= string,
        lProfile= string,
        imageId= string ,
        subnetIndex = string
    }))
}
variable "vpc_id" {
  description = "value of the vpc id"
  type = string
}
variable "subnets_map" {
    description = "Subnets"
    type = map(object({
            name = string,
            cidr = string,
            zone = string,
            prefix = string
        }))
}
variable "image-coreos" {
    description = "Image CoreOS"
    type = string
}
variable "image-windows" {
    description = "Image Windows"
    type = string
}
variable "script_path" {
    description = "Path to the script"
    type = string
}
variable "ssh_key_name" {
    description = "SSH Key Name"
    type = string
}
variable "ENABLE_HIGH_PERFORMANCE" {
    type = bool
}
variable "ibm_subnets_map" {
  description = "Subnets"
  type        = map(string)
}
variable "sg_id" {
    description = "Security Group ID"
    type = string
}
variable "subnets" {
    description = "Subnets"
    type = list(object({
            name = string,
            cidr = string,
            zone = string,
            prefix = string
        }))
}
variable "resource_group" {
    description = "Resource Group"
    type = string
}
variable "bastion-profile" {
    description = "Bastion profile"
    type = string
}