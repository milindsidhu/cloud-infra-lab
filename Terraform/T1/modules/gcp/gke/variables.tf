variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "network_name" {
  type        = string
  description = "VPC network name to create/use"
  default     = "gke-private-network"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR for GKE subnet"
  default     = "10.10.0.0/20"
}

variable "cluster_name" {
  type        = string
  description = "GKE cluster name"
  default     = "dev-gke"
}

variable "machine_type" {
  type        = string
  default     = "e2-medium"
}

variable "node_count" {
  type    = number
  default = 3
}

variable "node_service_account" {
  type        = string
  description = "Service account email for nodes. If empty will create one."
  default     = ""
}

variable "enable_private_nodes" {
  type    = bool
  default = true
}

variable "enable_private_endpoint" {
  type    = bool
  default = false
}

variable "authorized_networks" {
  type    = list(object({ cidr = string, description = string }))
  default = []
  description = "Master authorized networks for connecting to the control plane. Keep empty for no public control plane access."
}

variable "master_ipv4_cidr_block" {
  type        = string
  description = "CIDR block (/28) for GKE master nodes"
  default     = "172.16.0.0/28"
}

variable "ssh_public_key_path" {
  description = "Path to public SSH key"
  type        = string
}

variable "node_labels" {
  type = map(string)

  default = {
    env  = "dev"
    team = "platform"
  }

  validation {
    condition     = contains(keys(var.node_labels), "env")
    error_message = "Label 'env' is required."
  }

  validation {
    condition     = contains(keys(var.node_labels), "team")
    error_message = "Label 'team' is required."
  }
}
