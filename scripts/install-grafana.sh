#!/bin/bash
set -euo pipefail

GRAFANA_PASSWORD="$1"

# Add Grafana repository
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list

# Install Grafana
apt-get update -y
apt-get install -y grafana

# Configure Grafana
cat > /etc/grafana/grafana.ini << EOF
[server]
http_addr = 0.0.0.0
http_port = 3000

[security]
admin_user = admin
admin_password = $GRAFANA_PASSWORD

[auth.anonymous]
enabled = false
EOF

systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server
