variable "project" {
  description = "GCP project"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "compute_engines_names" {
  description = "List of VM names"
  type        = list(string)
}

variable "ssh_public_key_path" {
  description = "Path to public SSH key"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to private SSH key"
  type        = string
}

variable "common_labels" {
  description = "Common labels for resources"
  type        = map(string)
}

variable "vpc_ip_cidr_range" {
  description = "value for VPC subnet CIDR range"
  type        = string
  default     = "10.0.0.0/24"
}
