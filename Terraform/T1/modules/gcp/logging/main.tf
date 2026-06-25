# Enable APIs in central logging project
resource "google_project_service" "logging" {
  project = var.central_logging_project
  service = "logging.googleapis.com"
}

resource "google_project_service" "monitoring" {
  project = var.central_logging_project
  service = "monitoring.googleapis.com"
}

# Central Log Bucket
resource "google_logging_project_bucket_config" "central_bucket" {
  depends_on = [google_project_service.logging]

  project        = var.central_logging_project
  location       = "global"
  bucket_id      = var.central_bucket_id
  retention_days = var.central_bucket_retention_days
}

# Log Sinks in source projects
resource "google_logging_project_sink" "source_sinks" {
  for_each = toset(var.source_projects)

  name                   = var.sink_name
  project                = each.key
  destination            = "logging.googleapis.com/projects/${var.central_logging_project}/locations/global/buckets/${google_logging_project_bucket_config.central_bucket.bucket_id}"
  filter                 = var.sink_filter
  unique_writer_identity = true

  depends_on = [google_logging_project_bucket_config.central_bucket]
}

# # Give sink service account write access to central bucket
# resource "google_project_iam_member" "sink_bucket_writer" {
#   # for_each = google_logging_project_sink.source_sinks

#   project = var.central_logging_project
#   role    = "roles/logging.bucketWriter"
#   member  = var.sink_writer_service_account
# }
