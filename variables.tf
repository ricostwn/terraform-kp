# Variables for the GCP provider
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

# Variables for vpc
variable "region" {
  description = "The GCP region"
  default     = "asia-southeast2"
}

variable "ip_cidr_range" {
  description = "The IP CIDR range for the subnet"
  default     = "10.1.0.0/20"
}

# Variables for web server cluster
variable "web_server_count" {
  description = "Number of web servers in the cluster"
  default     = 2
}

variable "web_server_machine_type" {
  description = "Machine type for web servers"
  default     = "e2-medium"
}

variable "monitoring_machine_type" {
  description = "Machine type for monitoring server"
  default     = "e2-standard-2"
}

variable "monitoring_server_status" {
  description = "Desired status for the monitoring server"
  default     = "RUNNING"
}

variable "ssh_user" {
  description = "SSH username"
  default     = "53buahapel"
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  default     = "~/.ssh/id_ed25519"
}
