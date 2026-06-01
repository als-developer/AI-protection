# Sovereign Bio-Shield Ultimate Makefile
.PHONY: help build test lint docker-build docker-push deploy clean

VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
IMAGE_TAG ?= $(VERSION)

help:
	@echo "BioShield Ultimate Commands:"
	@echo "  make build        - Build all components"
	@echo "  make test         - Run all tests"
	@echo "  make lint         - Run linters"
	@echo "  make docker-build - Build Docker images"
	@echo "  make docker-push  - Push Docker images"
	@echo "  make deploy       - Deploy to production"
	@echo "  make clean        - Clean build artifacts"

build:
	@echo "Building C++ engine..."
	cd core && g++ -O3 -march=native -std=c++23 -c *.cpp
	@echo "Building Go exporter..."
	cd monitoring/prometheus/exporters && go build -o ebpf_exporter

test:
	@echo "Running unit tests..."
	pytest tests/unit/ -v --cov=api
	@echo "Running integration tests..."
	pytest tests/integration/ -v

lint:
	flake8 api/ --max-line-length=120
	black --check api/
	golangci-lint run monitoring/prometheus/exporters/

docker-build:
	docker build -f docker/Dockerfile.api -t bioshield/api:$(IMAGE_TAG) .
	docker build -f docker/Dockerfile.engine -t bioshield/engine:$(IMAGE_TAG) .
	docker tag bioshield/api:$(IMAGE_TAG) bioshield/api:latest
	docker tag bioshield/engine:$(IMAGE_TAG) bioshield/engine:latest

docker-push: docker-build
	docker push bioshield/api:$(IMAGE_TAG)
	docker push bioshield/engine:$(IMAGE_TAG)
	docker push bioshield/api:latest
	docker push bioshield/engine:latest

deploy:
	./scripts/deploy.sh production

clean:
	rm -f core/*.o core/*.so core/bioshield_engine
	rm -f monitoring/prometheus/exporters/ebpf_exporter
	./scripts/cleanup_sandbox.sh

dev-start:
	docker-compose -f docker/docker-compose.yml up -d
	./scripts/health_check.sh

dev-stop:
	docker-compose -f docker/docker-compose.yml down

.PHONY: upgrade rollback
upgrade:
	./scripts/upgrade.sh $(VERSION)

rollback:
	./scripts/rollback.sh $(PREVIOUS_VERSION)
