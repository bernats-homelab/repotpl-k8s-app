# Rode no WSL. O CI chama os mesmos scripts.
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

export PATH := $(HOME)/.local/bin:$(PATH)

.PHONY: help deps lint validate test build

help: ## Lista os targets
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

deps: ## Instala as ferramentas (versões e sha256 fixados) em ~/.local/bin
	./scripts/setup-tools.sh

lint: ## Todos os hooks do pre-commit em todos os arquivos
	pre-commit run --all-files

validate: ## kubeconform + kube-linter em deploy/ (base e overlays)
	./scripts/validate-manifests.sh

test: lint ## Tudo que roda sem cluster (o lint já inclui o validate)

build: ## Build local da imagem (precisa de Docker)
	docker build -t app-local .
