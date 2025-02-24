variable "vpc_name" {
  description = "Nombre de la VPC"
  type        = string
}
variable "resource_group" {
  description = "Resource Group"
  type        = string
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