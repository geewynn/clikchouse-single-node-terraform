global:
  scrape_interval: 30s
  evaluation_interval: 30s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['${server_ip}:9100']

  - job_name: 'clickhouse'
    static_configs:
      - targets: ['${server_ip}:9363']
    scrape_interval: 30s