resource "google_compute_network" "vpc_network" {
  name                    = "terraform-network"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnet" {
  name          = "terraform-subnet"
  ip_cidr_range = var.ip_cidr_range
  network       = google_compute_network.vpc_network.id
  region        = var.region
}

resource "google_compute_address" "static" {
  name   = "terraform-static-ip"
  region = var.region
}
