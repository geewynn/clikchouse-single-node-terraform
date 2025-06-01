package_upgrade: true

packages:
  - curl
  - wget
  - htop
  - unzip

users:
  - name: root
    ssh_authorized_keys:
      - ${ssh_public_key}

write_files:
  - path: /etc/sysctl.d/99-clickhouse.conf
    content: |
      vm.max_map_count = 262144
      vm.overcommit_memory = 1

runcmd:
  - sysctl -p /etc/sysctl.d/99-clickhouse.conf