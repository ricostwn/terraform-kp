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
