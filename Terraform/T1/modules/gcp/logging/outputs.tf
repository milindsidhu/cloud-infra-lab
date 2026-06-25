output "central_log_bucket" {
  value = google_logging_project_bucket_config.central_bucket.name
}

output "log_sinks" {
  value = { for k, v in google_logging_project_sink.source_sinks : k => v.name }
}

output "central_monitoring_project" {
  value = var.central_logging_project
}
