output "instance_ip" {
  description = "External IP address of the instance"
  value       = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}

output "instance_name" {
  description = "Name of the instance"
  value       = google_compute_instance.vm_instance.name
}
