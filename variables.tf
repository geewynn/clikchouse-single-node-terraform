variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = false
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cpx31"
}

variable "server_location" {
  description = "Hetzner server location"
  type        = string
  default     = "nbg1"
}

variable "volume_size" {
  description = "Size of additional volume for ClickHouse data in GB"
  type        = number
  default     = 100
  validation {
    condition     = var.volume_size >= 10 && var.volume_size <= 10000
    error_message = "Volume size must be between 10 and 10000 GB."
  }
}

variable "allowed_ips" {
  description = "List of IP addresses allowed to access ClickHouse"
  type        = list(string)
  default     = []
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "enable_monitoring" {
  description = "Enable Prometheus and Grafana monitoring"
  type        = bool
  default     = true
}

variable "clickhouse_password_hash" {
  description = "Clickhouse default admin password hash"
  type        = string
  default     = true
}