output "server_ip" {
  description = "ClickHouse server public IP"
  value       = hcloud_server.clickhouse.ipv4_address
}

output "server_private_ip" {
  description = "ClickHouse server private IP"
  value       = "10.0.1.10"
}

output "clickhouse_http_url" {
  description = "ClickHouse HTTP interface URL"
  value       = "http://${hcloud_server.clickhouse.ipv4_address}:8123"
}

output "clickhouse_admin_password" {
  description = "ClickHouse admin password"
  value       = var.clickhouse_password_hash
  sensitive   = true
}

output "grafana_url" {
  description = "Grafana URL (if monitoring enabled)"
  value       = var.enable_monitoring ? "http://${hcloud_server.clickhouse.ipv4_address}:3000" : null
}

output "grafana_admin_password" {
  description = "Grafana admin password (if monitoring enabled)"
  value       = var.enable_monitoring ? local.grafana_admin_password : null
  sensitive   = true
}

output "prometheus_url" {
  description = "Prometheus URL (if monitoring enabled)"
  value       = var.enable_monitoring ? "http://${hcloud_server.clickhouse.ipv4_address}:9090" : null
}

output "ssh_private_key" {
  description = "SSH private key for server access"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "connection_info" {
  description = "Connection information"
  value = {
    ssh_command = "echo '${tls_private_key.ssh.private_key_pem}' | ssh -i /dev/stdin root@${hcloud_server.clickhouse.ipv4_address}"
    clickhouse_cli = "clickhouse-client --host=${hcloud_server.clickhouse.ipv4_address} --password='${var.clickhouse_password_hash}'"
  }
  sensitive = true
}