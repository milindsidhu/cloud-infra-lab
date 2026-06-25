variable "central_logging_project" {
  description = "GCP project to act as centralized logging and monitoring project"
  type        = string
}

variable "central_bucket_id" {
  description = "Name of the central logging bucket"
  type        = string
  default     = "central-log-bucket"
}

variable "central_bucket_retention_days" {
  description = "Retention period for logs in the central bucket (days)"
  type        = number
  default     = 30
}

variable "source_projects" {
  description = "List of GCP projects sending logs to central logging project"
  type        = list(string)
  default     = []
}

variable "sink_name" {
  description = "Name of the log sink to create in source projects"
  type        = string
  default     = "export-to-central"
}

variable "sink_filter" {
  description = "Optional filter for logs to export"
  type        = string
  default     = ""
}

variable "sink_writer_service_account" {
  description = "value of the sink's writer identity"
  type        = string
  default     = "serviceAccount:terraform-sa@terraform-101-472115.iam.gserviceaccount.com "
}