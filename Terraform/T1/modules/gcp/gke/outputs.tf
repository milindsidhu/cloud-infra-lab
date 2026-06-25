output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "private_cluster_master_ipv4_cidr_block" {
  value = google_container_cluster.primary.private_cluster_config[0].master_ipv4_cidr_block
}

output "network" {
  value = google_compute_network.vpc.name
}

output "subnet" {
  value = google_compute_subnetwork.gke_subnet.name
}
