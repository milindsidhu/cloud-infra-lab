output "bastion_ip" {
  value = google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip
}

output "workload_private_ips" {
  value = { for name, vm in google_compute_instance.vm_instance : name => vm.network_interface[0].network_ip }
}

output "ansible_inventory_file" {
  value = local_file.ansible_inventory.filename
}
