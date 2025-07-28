resource "google_compute_instance" "vm_instance" {
  name                      = "instance-monitoring"
  machine_type              = "custom-2-4096"
  allow_stopping_for_update = true

  desired_status = "TERMINATED" # Set to "RUNNING" or "TERMINATED" based on the variable

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
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

  # Wait for the instance to be ready
  provisioner "remote-exec" {
    inline = [
      "echo 'Instance is ready for configuration'",
      "sudo apt-get update -y"
    ]

    connection {
      type        = "ssh"
      user        = "53buahapel"
      private_key = file("~/.ssh/id_ed25519")
      host        = self.network_interface[0].access_config[0].nat_ip
      timeout     = "5m"
    }
  }

  # Run Ansible playbook
  provisioner "local-exec" {
    command = "cd ansible && ansible-playbook -i '${self.network_interface[0].access_config[0].nat_ip},' -u 53buahapel --private-key ~/.ssh/id_ed25519 setup.yml"
  }
}
