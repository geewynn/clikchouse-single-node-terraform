locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "clickhouse"
  }
  
  server_name = "${var.project_name}-clickhouse-${var.environment}"
  grafana_admin_password    = random_password.grafana_admin.result
}

# ================================
# RANDOM PASSWORDS
# ================================

resource "random_password" "grafana_admin" {
  length  = 16
  special = false  # Grafana admin - keep it simple
}

# ================================
# TLS CERTIFICATES (for internal communication)
# ================================

resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "${local.server_name}-ca"
    organization = var.project_name
  }

  validity_period_hours = 8760 # 1 year
  is_ca_certificate     = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
  ]
}

# ================================
# SSH KEY MANAGEMENT
# ================================

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "hcloud_ssh_key" "main" {
  name       = "${local.server_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
  labels     = local.common_tags
}

# ================================
# NETWORKING
# ================================

resource "hcloud_network" "main" {
  name     = "${local.server_name}-network"
  ip_range = "10.0.0.0/16"
  labels   = local.common_tags
}

resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

# ================================
# FIREWALL CONFIGURATION
# ================================

resource "hcloud_firewall" "clickhouse" {
  name   = "${local.server_name}-firewall"
  labels = local.common_tags

  # SSH access - restricted
  rule {
    direction   = "in"
    port        = "22"
    protocol    = "tcp"
    source_ips  = length(var.allowed_ips) > 0 ? var.allowed_ips : ["0.0.0.0/0"]
    description = "SSH access"
  }

  # ClickHouse HTTP interface - restricted
  rule {
    direction   = "in"
    port        = "8123"
    protocol    = "tcp"
    source_ips  = length(var.allowed_ips) > 0 ? var.allowed_ips : ["0.0.0.0/0"]
    description = "ClickHouse HTTP"
  }

  # ClickHouse native protocol - restricted
  rule {
    direction   = "in"
    port        = "9000"
    protocol    = "tcp"
    source_ips  = length(var.allowed_ips) > 0 ? var.allowed_ips : ["0.0.0.0/0"]
    description = "ClickHouse Native"
  }

  # HTTPS (for reverse proxy)
  rule {
    direction   = "in"
    port        = "443"
    protocol    = "tcp"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "HTTPS"
  }

  # Monitoring (conditional)
  dynamic "rule" {
    for_each = var.enable_monitoring ? [1] : []
    content {
      direction   = "in"
      port        = "3000"
      protocol    = "tcp"
      source_ips  = length(var.allowed_ips) > 0 ? var.allowed_ips : ["0.0.0.0/0"]
      description = "Grafana"
    }
  }

  dynamic "rule" {
    for_each = var.enable_monitoring ? [1] : []
    content {
      direction   = "in"
      port        = "9090"
      protocol    = "tcp"
      source_ips  = length(var.allowed_ips) > 0 ? var.allowed_ips : ["0.0.0.0/0"]
      description = "Prometheus"
    }
  }

  # Node exporter (internal only)
  rule {
    direction   = "in"
    port        = "9100"
    protocol    = "tcp"
    source_ips  = ["10.0.0.0/16"]
    description = "Node Exporter (internal)"
  }

  # ClickHouse metrics (internal only)
  rule {
    direction   = "in"
    port        = "9363"
    protocol    = "tcp"
    source_ips  = ["10.0.0.0/16"]
    description = "ClickHouse Metrics (internal)"
  }

  # ICMP
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

}

resource "hcloud_server" "clickhouse" {
  name         = local.server_name
  image        = "ubuntu-24.04"
  server_type  = var.server_type
  location     = var.server_location
  ssh_keys     = [hcloud_ssh_key.main.id]
  firewall_ids = [hcloud_firewall.clickhouse.id]
  labels       = local.common_tags

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  user_data = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    ssh_public_key = tls_private_key.ssh.public_key_openssh
  })

  lifecycle {
    ignore_changes = [user_data]
  }
}

# Cloud-init configuration
resource "local_file" "cloud_init" {
  filename = "${path.module}/cloud-init.yml"
  content = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    ssh_public_key = tls_private_key.ssh.public_key_openssh
  })
}

# ClickHouse configuration
resource "local_file" "clickhouse_config" {
  filename = "${path.module}/configs/clickhouse-config.xml"
  content = templatefile("${path.module}/templates/clickhouse-config.xml.tpl", {})
}

resource "local_file" "clickhouse_password" {
  filename = "${path.module}/configs/ch-default-password.xml"
  content = templatefile("${path.module}/templates/ch-default-password.xml.tpl", {
    clickhouse_password_hash = var.clickhouse_password_hash
  })
}

# Prometheus configuration
resource "local_file" "prometheus_config" {
  count    = var.enable_monitoring ? 1 : 0
  filename = "${path.module}/configs/prometheus.yml"
  content = templatefile("${path.module}/templates/prometheus.yml.tpl", {
    server_ip = hcloud_server.clickhouse.ipv4_address
  })
}

# ================================
# Deployment
# ================================

resource "null_resource" "clickhouse_deployment" {
  depends_on = [
    hcloud_server.clickhouse,
    local_file.clickhouse_config,
  ]

  triggers = {
    server_id               = hcloud_server.clickhouse.id
    clickhouse_config_hash  = local_file.clickhouse_config.content_md5
    deployment_script_hash  = filemd5("${path.module}/scripts/deploy.sh")
  }

  connection {
    type        = "ssh"
    host        = hcloud_server.clickhouse.ipv4_address
    user        = "root"
    private_key = tls_private_key.ssh.private_key_pem
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/configs",
      "mkdir -p /tmp/scripts"
    ]
  }

  # Upload configurations
  provisioner "file" {
    source      = "${path.module}/configs/"
    destination = "/tmp/configs/"
  }

  # Upload scripts
  provisioner "file" {
    source      = "${path.module}/scripts/"
    destination = "/tmp/scripts/"
  }
  
  # Execute deployment
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/scripts/*.sh",
      "CLICKHOUSE_PASSWORD='${var.clickhouse_password_hash}' GRAFANA_PASSWORD='${local.grafana_admin_password}' ENABLE_MONITORING='${var.enable_monitoring}' /tmp/scripts/deploy.sh"
    ]
  }
}


# ================================
# Health Checks
# ================================
resource "null_resource" "health_checks" {
  depends_on = [null_resource.clickhouse_deployment]

  triggers = {
    always_run = timestamp()
  }

  connection {
    type        = "ssh"
    host        = hcloud_server.clickhouse.ipv4_address
    user        = "root"
    private_key = tls_private_key.ssh.private_key_pem
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Running health checks...'",
      # Wait for services
      "sleep 30",
      # Check ClickHouse
      "systemctl is-active clickhouse-server || exit 1",
      "curl -f 'http://localhost:8123/ping' || exit 1",
      
      # Check monitoring if enabled
      var.enable_monitoring ? "systemctl is-active prometheus || exit 1" : "echo 'Monitoring disabled'",
      var.enable_monitoring ? "systemctl is-active grafana-server || exit 1" : "echo 'Monitoring disabled'",
      var.enable_monitoring ? "curl -f 'http://localhost:9090/-/healthy' || exit 1" : "echo 'Monitoring disabled'",
      var.enable_monitoring ? "curl -f 'http://localhost:3000/api/health' || exit 1" : "echo 'Monitoring disabled'",
      
      "echo 'All health checks passed!'"
    ]
  }
}

