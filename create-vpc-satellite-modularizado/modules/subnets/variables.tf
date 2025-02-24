variable "subnets" {
  description = "Subnets"
  type = list(object({
        name = string,
        cidr = string,
        zone = string,
        prefix = string
    }))
}
variable "vpc_id" {
  description = "value of the vpc id"
  type = string
}
variable "resource_group" {
  description = "Resource Group"
  type        = string
}