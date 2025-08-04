# Monitoring Server (Load Balancer + Prometheus + Grafana)
resource "google_compute_instance" "monitoring_server" {
  name                      = "monitoring-server"
  machine_type              = var.monitoring_machine_type
  allow_stopping_for_update = true
  desired_status = var.monitoring_server_status

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 20
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnet.name
    access_config {
      nat_ip = google_compute_address.static.address
    }
  }

  tags = ["monitoring"]

  metadata = {
    ssh-keys = "${var.ssh_user}:${file("${var.ssh_key_path}.pub")}"
  }

  # Wait for the instance to be ready
  provisioner "remote-exec" {
    inline = [
      "echo 'Monitoring server is ready for configuration'",
      "sudo apt-get update -y"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_key_path)
      host        = self.network_interface[0].access_config[0].nat_ip
      timeout     = "5m"
    }
  }
}

# Web Server Cluster
resource "google_compute_instance" "web_servers" {
  count                     = var.web_server_count
  name                      = "web-server-${count.index + 1}"
  machine_type              = var.web_server_machine_type
  allow_stopping_for_update = true
  desired_status = "RUNNING"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnet.name
    access_config {
      # Ephemeral IP
    }
  }

  tags = ["web-server"]

  metadata = {
    ssh-keys = "${var.ssh_user}:${file("${var.ssh_key_path}.pub")}"
  }

  # Wait for the instance to be ready
  provisioner "remote-exec" {
    inline = [
      "echo 'Web server ${count.index + 1} is ready for configuration'",
      "sudo apt-get update -y"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_key_path)
      host        = self.network_interface[0].access_config[0].nat_ip
      timeout     = "5m"
    }
  }
}

# Generate Ansible inventory after all instances are created
resource "local_file" "ansible_inventory" {
  depends_on = [google_compute_instance.monitoring_server, google_compute_instance.web_servers]
  
  content = templatefile("${path.module}/ansible/inventory.tpl", {
    monitoring_server_ip = google_compute_instance.monitoring_server.network_interface[0].access_config[0].nat_ip
    monitoring_server_internal_ip = google_compute_instance.monitoring_server.network_interface[0].network_ip
    web_servers = [
      for i, server in google_compute_instance.web_servers : {
        name = server.name
        ip = server.network_interface[0].access_config[0].nat_ip
        internal_ip = server.network_interface[0].network_ip
      }
    ]
    ssh_user = var.ssh_user
  })
  
  filename = "${path.module}/ansible/inventory.ini"
}
