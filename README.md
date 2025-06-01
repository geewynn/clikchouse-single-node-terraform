# clikchouse-single-node-terraform

# ClickHouse Terraform Deployment

A production-ready Terraform configuration for deploying ClickHouse on Hetzner Cloud with optional monitoring stack (Prometheus, Grafana, Node Exporter).

## Features

- **Secure ClickHouse deployment** with password-protected access
- **Cloud firewall protection** with restricted access rules
- **Optional monitoring stack** (Prometheus, Grafana, Node Exporter)
- **Automated SSL certificate generation** for internal communication
- **SSH key management** with auto-generated keys
- **Health checks** to verify deployment success
- **Easy local access** via SSH tunnels

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Hetzner Cloud API Token](https://docs.hetzner.com/cloud/api/getting-started/generating-api-token/)
- `make` (for using the Makefile commands)

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/geewynn/clikchouse-single-node-terraform.git
cd clikchouse-single-node-terraform
```

### 2. Configure Hetzner API Token

```bash
export HCLOUD_TOKEN="your-hetzner-api-token"
```

### 3. Create Configuration Files

**Create `terraform.tfvars`:**
```hcl
hcloud_token=""
project_name = "my-analytics"
environment = "prod"
server_type = "cx21"
server_location = "nbg1"
enable_monitoring = true

# Generate this with: echo -n 'your_password' | sha256sum | cut -d' ' -f1
clickhouse_password_hash = "your_sha256_password_hash_here"

# Optional: Restrict access to specific IPs
allowed_ips = ["1.2.3.4/32", "5.6.7.8/32"]
```

**Create `state.config` (optional, for remote state):**
```hcl
bucket = "your-terraform-state-bucket"
key    = "clickhouse/terraform.tfstate"
region = "us-west-2"
profile= "your-aws-profile"
```

### 4. Deploy

```bash
# Initialize Terraform
make init

# Plan deployment
make plan

# Deploy infrastructure
make apply
```

### 5. Access Your Services

```bash
# Show connection info
make outputs

# SSH into server
make ssh

# Start local tunnels for easy access
make tunnel-start
```

## Project Structure

```
.
├── main.tf                           # Main Terraform configuration
├── variables.tf                      # Variable definitions
├── outputs.tf                        # Output definitions
├── terraform.tfvars                  # Your configuration values
├── state.config                      # Remote state configuration
├── makefile                          # Automation commands
├── scripts/
│   ├── deploy.sh                     # Main deployment script
│   ├── install-prometheus.sh         # Prometheus installation
│   ├── install-grafana.sh           # Grafana installation
│   └── install-node-exporter.sh     # Node Exporter installation
├── templates/
│   ├── cloud-init.yml.tpl           # Cloud-init configuration
│   ├── clickhouse-config.xml.tpl    # ClickHouse server config
│   ├── ch-default-password.xml.tpl  # ClickHouse password config
│   └── prometheus.yml.tpl           # Prometheus configuration
└── configs/                         # Generated configuration files
```

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_name` | Project identifier | `"my-analytics"` |
| `environment` | Environment name | `"prod"` |
| `clickhouse_password_hash` | SHA256 hash of ClickHouse password | `"e3b0c44..."` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `server_type` | Hetzner server type | `"cx21"` |
| `server_location` | Hetzner location | `"nbg1"` |
| `enable_monitoring` | Install monitoring stack | `true` |
| `allowed_ips` | IPs allowed to access services | `[]` (all) |

### Generating Password Hash

```bash
# Method 1: Using sha256sum
echo -n 'your_actual_password' | sha256sum | cut -d' ' -f1

# Method 2: Using Python
python3 -c "import hashlib; print(hashlib.sha256('your_actual_password'.encode()).hexdigest())"
```

## 🎯 Makefile Commands

| Command | Description |
|---------|-------------|
| `make help` | Show available commands |
| `make init` | Initialize Terraform |
| `make validate` | Validate and format Terraform files |
| `make plan` | Plan deployment changes |
| `make apply` | Deploy infrastructure |
| `make destroy` | Destroy all resources |
| `make ssh` | SSH into the ClickHouse server |
| `make tunnel-start` | Start SSH tunnels for local access |
| `make outputs` | Show connection information |
| `make clean` | Clean up temporary files |

## 🌐 Service Access

### After Deployment

**Direct Access (if IP is allowed):**
- ClickHouse HTTP: `http://your-server-ip:8123`
- ClickHouse Native: `your-server-ip:9000`
- Grafana: `http://your-server-ip:3000`
- Prometheus: `http://your-server-ip:9090`

**Local Access via SSH Tunnels:**
```bash
make tunnel-start
```
Then access:
- ClickHouse: `http://localhost:8123`
- Grafana: `http://localhost:3000` (admin/password from outputs)
- Prometheus: `http://localhost:9090`

### ClickHouse Connection Examples

**HTTP Interface:**
```bash
curl -u default:your_password 'http://localhost:8123/?query=SELECT%201'
```

**Native Client:**
```bash
clickhouse-client --host=your-server-ip --password='your_password'
```

**Python (using clickhouse-driver):**
```python
from clickhouse_driver import Client

client = Client(
    host='your-server-ip',
    user='default',
    password='your_password'
)

result = client.execute('SELECT 1')
```

## Security Features

- **Cloud firewall** with restricted port access
- **SSH key authentication** (password login disabled)
- **Strong password requirements** for ClickHouse
- **Optional IP allowlist** for service access
- **Internal network isolation** for metrics endpoints

## Monitoring

When `enable_monitoring = true`, you get:

- **Prometheus** collecting metrics from ClickHouse and system
- **Grafana** for visualization and dashboards
- **Node Exporter** for system metrics (CPU, memory, disk, network)

### Default Metrics Collected

- ClickHouse query performance and errors
- System resources (CPU, memory, disk I/O)
- Network statistics
- Service health status

## Troubleshooting

### Common Issues

**1. Deployment Hangs During ClickHouse Installation**
```bash
# Check if password pre-seeding is working
make ssh
sudo ps aux | grep -E "(apt|dpkg|clickhouse)"
```

**2. Can't Connect to ClickHouse**
```bash
# Check service status
make ssh
systemctl status clickhouse-server

# Check logs
sudo tail -f /var/log/clickhouse-server/clickhouse-server.log
```

**3. Terraform Timeout Errors**
- Try setting `enable_monitoring = false` for faster initial deployment
- Check network connectivity to Hetzner and GitHub

### Debugging Commands

```bash
# View deployment logs
make ssh
sudo tail -f /var/log/clickhouse-deployment.log

# Check all services
systemctl status clickhouse-server prometheus grafana-server node_exporter

# Test ClickHouse connectivity
echo "SELECT 1" | clickhouse-client --password='your_password'
```

## Updates and Maintenance

### Updating Configuration

1. Modify `terraform.tfvars`
2. Run `make plan` to see changes
3. Run `make apply` to deploy updates

### Scaling

To change server size:
1. Update `server_type` in `terraform.tfvars`
2. Run `make apply`
3. Note: This will recreate the server and lose data unless backed up

## Cleanup

```bash
# Destroy all resources
make destroy

# Clean up local files
make clean
```
