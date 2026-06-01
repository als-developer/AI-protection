# Sovereign Bio-Shield Ultimate Makefile

.PHONY: help build deploy clean test lint docker-build docker-push kubectl-deploy

help:
	@echo "BioShield Ultimate Makefile Commands:"
	@echo "  make build          - Build all components"
	@echo "  make deploy         - Deploy to production"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make test           - Run all tests"
	@echo "  make lint           - Run linters"
	@echo "  make docker-build   - Build Docker images"
	@echo "  make docker-push    - Push Docker images"
	@echo "  make kubectl-deploy - Deploy to Kubernetes"

build:
	@echo "Building C++ engine..."
	cd core && make
	@echo "Building Go exporter..."
	cd monitoring/prometheus/exporters && go build -o ebpf_exporter ebpf_exporter.go

deploy:
	@echo "Deploying BioShield Ultimate..."
	./scripts/deploy.sh production

clean:
	@echo "Cleaning build artifacts..."
	rm -f core/*.o core/*.so core/bioshield_engine
	rm -f monitoring/prometheus/exporters/ebpf_exporter
	./scripts/cleanup_sandbox.sh

test:
	@echo "Running unit tests..."
	pytest tests/unit/ -v
	@echo "Running integration tests..."
	pytest tests/integration/ -v

lint:
	@echo "Running linters..."
	flake8 api/ --max-line-length=120
	black --check api/
	gofmt -l monitoring/prometheus/exporters/

docker-build:
	@echo "Building Docker images..."
	docker build -f docker/Dockerfile.api -t bioshield/api:latest .
	docker build -f docker/Dockerfile.engine -t bioshield/engine:latest .

docker-push:
	@echo "Pushing Docker images..."
	docker push bioshield/api:latest
	docker push bioshield/engine:latest

kubectl-deploy:
	@echo "Deploying to Kubernetes..."
	kubectl apply -f infra/kubernetes/namespace.yaml
	kubectl apply -f infra/kubernetes/configmap.yaml
	kubectl apply -f infra/kubernetes/secret.yaml
	kubectl apply -f infra/kubernetes/deployment.yaml
	kubectl apply -f infra/kubernetes/service.yaml
	kubectl rollout status deployment/bioshield-api -n bioshield-system

.PHONY: dev-start dev-stop
dev-start:
	docker-compose -f docker/docker-compose.yml up -d

dev-stop:
	docker-compose -f docker/docker-compose.yml down
