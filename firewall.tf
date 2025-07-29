resource "google_compute_firewall" "allow_icmp" {
  name    = "terraform-allow-icmp"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 65534
}

resource "google_compute_firewall" "allow_internal" {
  name    = "terraform-allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.ip_cidr_range]
  direction     = "INGRESS"
  priority      = 65534
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "terraform-allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 65534
}

resource "google_compute_firewall" "allow_grafana" {
  name    = "terraform-allow-grafana"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 65534

  target_tags = ["monitoring"]
}

# Firewall rule for web traffic (HTTP/HTTPS)
resource "google_compute_firewall" "allow_web" {
  name    = "terraform-allow-web"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 65534

  target_tags = ["monitoring", "web-server"]
}

# Firewall rule for Node Exporter
resource "google_compute_firewall" "allow_node_exporter" {
  name    = "terraform-allow-node-exporter"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["9100"]
  }

  source_ranges = [var.ip_cidr_range]
  direction     = "INGRESS"
  priority      = 65534

  target_tags = ["web-server"]
}

# Firewall rule for Prometheus
resource "google_compute_firewall" "allow_prometheus" {
  name    = "terraform-allow-prometheus"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["9090"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 65534

  target_tags = ["monitoring"]
}

# Firewall rule for application ports
resource "google_compute_firewall" "allow_app_ports" {
  name    = "terraform-allow-app-ports"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["3000", "8080", "8000"]
  }

  source_ranges = [var.ip_cidr_range]
  direction     = "INGRESS"
  priority      = 65534

  target_tags = ["web-server"]
}
