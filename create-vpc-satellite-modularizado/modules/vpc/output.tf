output "vpc_id" {
  description = "value of the vpc id"
   value       = ibm_is_vpc.cluster-vpc.id
}