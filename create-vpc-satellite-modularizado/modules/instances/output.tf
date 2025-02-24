output "fip_bastion" {
  value = ibm_is_floating_ip.fip_bastion.address
}

output "bastion_password_command" {
  value = "ibmcloud is instance-initialization-values ${ibm_is_instance.bastion.id} --private-key '@~/.ssh/id_rsa'"
}