resource "google_compute_instance" "vm_instance" {
  name                      = "instance-monitoring"
  machine_type              = "n1-standard-4"
  allow_stopping_for_update = true

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
}
