.PHONY: help init plan apply destroy ssh tunnel-start tunnel-stop outputs clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform
	terraform init -backend-config="./state.config"

validate: ## Validate Terraform configuration
	terraform validate
	terraform fmt -check

plan: ## Plan Terraform deployment
	terraform plan -var-file="terraform.tfvars"

apply: ## Apply Terraform deployment
	terraform apply -var-file="terraform.tfvars" -auto-approve

destroy: ## Destroy infrastructure
	terraform destroy -var-file="terraform.tfvars" -auto-approve

ssh: ## SSH into the server
	@echo "Connecting to ClickHouse server..."
	@terraform output -raw ssh_private_key > /tmp/clickhouse_key
	@chmod 600 /tmp/clickhouse_key
	@ssh -i /tmp/clickhouse_key root@$(shell terraform output -raw server_ip)
	@rm /tmp/clickhouse_key

tunnel-start: ## Start SSH tunnels for local access
	@echo "Starting SSH tunnels..."
	@terraform output -raw ssh_private_key > /tmp/clickhouse_key
	@chmod 600 /tmp/clickhouse_key
	@echo "SSH tunnels started. Access services at:"
	@echo "  ClickHouse: http://localhost:8123"
	@echo "  Grafana: http://localhost:3000"
	@echo "  Prometheus: http://localhost:9090"
	@echo "Press Ctrl+C to stop tunnels"
	@ssh -i /tmp/clickhouse_key \
		-L 8123:localhost:8123 \
		-L 3000:localhost:3000 \
		-L 9090:localhost:9090 \
		-L 9000:localhost:9000 \
		-N root@$(shell terraform output -raw server_ip) || rm /tmp/clickhouse_key

outputs: ## Show deployment outputs
	@echo "=== ClickHouse Connection Info ==="
	@echo "Server IP: $(shell terraform output -raw server_ip)"
	@echo "ClickHouse URL: $(shell terraform output -raw clickhouse_http_url)"
	@echo "Grafana URL: $(shell terraform output -raw grafana_url || echo 'N/A')"
	@echo "Prometheus URL: $(shell terraform output -raw prometheus_url || echo 'N/A')"
	@echo ""
	@echo "=== Passwords ==="
	@echo "ClickHouse Admin: $(shell terraform output -raw clickhouse_admin_password)"
	@echo "Grafana Admin: admin / $(shell terraform output -raw grafana_admin_password || echo 'N/A')"

clean: ## Clean up temporary files
	rm -f /tmp/clickhouse_key
	rm -rf .terraform/
	rm -f terraform.tfstate.backup