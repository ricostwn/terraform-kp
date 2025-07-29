output "monitoring_server_ip" {
  description = "External IP address of the monitoring server"
  value       = google_compute_instance.monitoring_server.network_interface[0].access_config[0].nat_ip
}

output "monitoring_server_internal_ip" {
  description = "Internal IP address of the monitoring server"
  value       = google_compute_instance.monitoring_server.network_interface[0].network_ip
}

output "web_servers_ips" {
  description = "External IP addresses of web servers"
  value       = [for instance in google_compute_instance.web_servers : instance.network_interface[0].access_config[0].nat_ip]
}

output "web_servers_internal_ips" {
  description = "Internal IP addresses of web servers"
  value       = [for instance in google_compute_instance.web_servers : instance.network_interface[0].network_ip]
}

output "web_servers_names" {
  description = "Names of web server instances"
  value       = [for instance in google_compute_instance.web_servers : instance.name]
}

output "load_balancer_url" {
  description = "Load balancer URL"
  value       = "http://${google_compute_instance.monitoring_server.network_interface[0].access_config[0].nat_ip}"
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${google_compute_instance.monitoring_server.network_interface[0].access_config[0].nat_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${google_compute_instance.monitoring_server.network_interface[0].access_config[0].nat_ip}:9090"
}

output "grafana_credentials" {
  description = "Grafana login credentials"
  value       = "Username: admin, Password: admin123"
  sensitive   = true
}
