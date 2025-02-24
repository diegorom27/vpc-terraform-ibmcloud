output "sg_id" {
  description = "value of the security group id"  
  value = ibm_is_security_group.cluster-sg.id
}