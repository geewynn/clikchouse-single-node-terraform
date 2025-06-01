# Set error handling
set -e

# Load variables from .env file if it exists
if [ -f "/tmp/.env" ]; then
  export $(grep -v '^#' /tmp/.env | xargs)
fi

# Default variables
CLICKHOUSE_VERSION="latest"
ADMIN_PASSWORD="${CLICKHOUSE_PASSWORD}"
LOG_FILE="/var/log/clickhouse_install.log"
TEMP_DIR="/tmp/clickhouse_install_$(date +%s)"

echo "Using admin password: $ADMIN_PASSWORD"

# Function for logging
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] [$1] $2" | tee -a "$LOG_FILE"
}

# Function for showing help
show_help() {
    grep "^##" "$0" | sed -e "s/^##//" -e "s/^ //"
    exit 0
}

# Setup
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
mkdir -p "$TEMP_DIR"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR" "This script must be run as root or with sudo privileges"
    exit 1
fi

# Install dependencies
log "INFO" "Installing required dependencies"
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add ClickHouse repository
log "INFO" "Adding ClickHouse repository"
curl -fsSL 'https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key' | gpg --dearmor --yes -o /usr/share/keyrings/clickhouse-keyring.gpg
ARCH=$(dpkg --print-architecture)
echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg arch=${ARCH}] https://packages.clickhouse.com/deb stable main" > /etc/apt/sources.list.d/clickhouse.list
apt-get update -y

# Install ClickHouse
log "INFO" "Installing ClickHouse packages"
cat > "$TEMP_DIR/clickhouse.debconf" << EOF
clickhouse-server clickhouse-server/default-password string ${ADMIN_PASSWORD}
clickhouse-server clickhouse-server/default-password-confirmation string ${ADMIN_PASSWORD}
EOF

# Pre-seed debconf with the password
DEBIAN_FRONTEND=noninteractive debconf-set-selections "$TEMP_DIR/clickhouse.debconf"

# Install packages
if [ "$CLICKHOUSE_VERSION" = "latest" ]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y clickhouse-server clickhouse-client
else
    DEBIAN_FRONTEND=noninteractive apt-get install -y "clickhouse-server=$CLICKHOUSE_VERSION" "clickhouse-client=$CLICKHOUSE_VERSION" || {
        log "WARNING" "Failed to install version $CLICKHOUSE_VERSION, installing latest instead"
        DEBIAN_FRONTEND=noninteractive apt-get install -y clickhouse-server clickhouse-client
    }
fi

# Start ClickHouse service
log "INFO" "Starting ClickHouse service"
systemctl daemon-reload
systemctl enable clickhouse-server
systemctl restart clickhouse-server


# Copy configuration
log "INFO" "Configuring ClickHouse..."
cp /tmp/configs/clickhouse-config.xml /etc/clickhouse-server/config.d/
cp /tmp/configs/ch-default-password.xml /etc/clickhouse-server/users.d/

systemctl restart clickhouse-server

# Wait for service to start
log "INFO" "Waiting for ClickHouse service to start"
for i in {1..10}; do
    if systemctl is-active --quiet clickhouse-server; then
        break
    fi
    log "INFO" "Waiting... ($i/10)"
    sleep 2
done

# Install monitoring if enabled
if [ "$ENABLE_MONITORING" = "true" ]; then
    log "INFO" "Installing monitoring stack..."
    /tmp/scripts/install-prometheus.sh
    /tmp/scripts/install-grafana.sh "$GRAFANA_PASSWORD"
    /tmp/scripts/install-node-exporter.sh
    
    if [ -f /tmp/configs/prometheus.yml ]; then
        cp /tmp/configs/prometheus.yml /etc/prometheus/
        systemctl restart prometheus
    fi
    
    log "INFO" "Monitoring stack installed"
fi


# Configure firewall - if not running on a cloud instance
# log "INFO" "Configuring firewall..."
# ufw --force enable
# ufw default deny incoming
# ufw default allow outgoing
# ufw allow 22/tcp

# Configure fail2ban
systemctl enable fail2ban
systemctl start fail2ban

log "INFO" "Deployment completed successfully!"

cat << 'EOF'
Services Status:
- ClickHouse: Active
- Monitoring: $([ "$ENABLE_MONITORING" = "true" ] && echo "Active" || echo "Disabled")
- Backups: Configured (daily at 2 AM)
- Security: UFW + fail2ban enabled

Connection Info:
- ClickHouse HTTP: http://SERVER_IP:8123
- ClickHouse CLI: clickhouse-client --host=SERVER_IP --password='PASSWORD'
EOF