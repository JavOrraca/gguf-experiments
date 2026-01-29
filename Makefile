# =============================================================================
# GGUF Experiments - Makefile
# =============================================================================
# Simple commands for working with larger-than-RAM LLMs on macOS
#
# Quick Start:
#   make setup     - Install dependencies
#   make download  - Download the Llama 4 Scout model
#   make chat      - Start interactive chat
#   make serve     - Start OpenAI-compatible API server
#
# Type 'make help' for all available commands
# =============================================================================

.PHONY: help setup download chat query serve stop clean info test

# Default target
.DEFAULT_GOAL := help

# Configuration
SHELL := /bin/bash
SCRIPTS_DIR := ./scripts
CONFIG_FILE := ./config.env

# Colors for pretty output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

# =============================================================================
# HELP
# =============================================================================

help: ## Show this help message
	@echo ""
	@echo "$(BLUE)GGUF Experiments - Larger-than-RAM LLM Inference$(NC)"
	@echo ""
	@echo "$(GREEN)Quick Start:$(NC)"
	@echo "  make setup      Install dependencies (llama.cpp, huggingface-cli)"
	@echo "  make download   Download the Llama 4 Scout GGUF model"
	@echo "  make chat       Start interactive chat session"
	@echo ""
	@echo "$(GREEN)Available Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-12s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Configuration:$(NC)"
	@echo "  Edit config.env to customize RAM limits and other settings"
	@echo ""

# =============================================================================
# SETUP & INSTALLATION
# =============================================================================

setup: ## Install all dependencies (llama.cpp, huggingface-cli)
	@chmod +x $(SCRIPTS_DIR)/*.sh
	@$(SCRIPTS_DIR)/setup.sh

download: ## Download the Llama 4 Scout GGUF model (~35GB)
	@$(SCRIPTS_DIR)/download-model.sh

# =============================================================================
# INFERENCE
# =============================================================================

chat: ## Start interactive chat session
	@$(SCRIPTS_DIR)/chat.sh

query: ## Run a single query (usage: make query PROMPT="your question")
	@if [ -z "$(PROMPT)" ]; then \
		echo "Usage: make query PROMPT=\"your question here\""; \
		exit 1; \
	fi
	@$(SCRIPTS_DIR)/query.sh "$(PROMPT)"

serve: ## Start the OpenAI-compatible API server
	@$(SCRIPTS_DIR)/serve.sh

stop: ## Stop the running API server
	@echo "Stopping llama-server..."
	@pkill -f "llama-server" 2>/dev/null || echo "No server running"
	@echo "Server stopped"

# =============================================================================
# UTILITIES
# =============================================================================

info: ## Show system information and model status
	@echo ""
	@echo "$(BLUE)System Information$(NC)"
	@echo "=================="
	@echo "OS: $$(uname -s) $$(uname -r)"
	@echo "Chip: $$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Unknown')"
	@echo "RAM: $$(( $$(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))GB"
	@echo ""
	@echo "$(BLUE)llama.cpp Status$(NC)"
	@echo "================"
	@which llama-cli 2>/dev/null && llama-cli --version 2>&1 | head -1 || echo "Not installed - run 'make setup'"
	@echo ""
	@echo "$(BLUE)Model Status$(NC)"
	@echo "============"
	@if [ -d "./models" ]; then \
		ls -lh ./models/*.gguf 2>/dev/null || echo "No models downloaded - run 'make download'"; \
	else \
		echo "No models directory - run 'make setup' then 'make download'"; \
	fi
	@echo ""
	@echo "$(BLUE)Configuration$(NC)"
	@echo "============="
	@if [ -f "$(CONFIG_FILE)" ]; then \
		echo "RAM_LIMIT: $$(grep '^RAM_LIMIT=' $(CONFIG_FILE) | cut -d'=' -f2)"; \
		echo "GPU_LAYERS: $$(grep '^GPU_LAYERS=' $(CONFIG_FILE) | cut -d'=' -f2)"; \
		echo "CONTEXT_SIZE: $$(grep '^CONTEXT_SIZE=' $(CONFIG_FILE) | cut -d'=' -f2)"; \
	else \
		echo "No config.env found - using defaults"; \
	fi
	@echo ""

test: ## Test inference with a simple prompt
	@echo "Testing inference..."
	@$(SCRIPTS_DIR)/query.sh "Say hello in exactly 5 words."

clean: ## Remove downloaded models and generated files
	@echo "$(YELLOW)Warning: This will delete all downloaded models!$(NC)"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@rm -rf ./models/*.gguf
	@echo "Cleaned models directory"

# =============================================================================
# DEVELOPMENT
# =============================================================================

lint: ## Check shell scripts for errors
	@echo "Checking scripts..."
	@shellcheck $(SCRIPTS_DIR)/*.sh 2>/dev/null || echo "Install shellcheck: brew install shellcheck"

config: ## Open config.env in your editor
	@if [ ! -f "$(CONFIG_FILE)" ]; then \
		cp config.env.example $(CONFIG_FILE); \
		echo "Created $(CONFIG_FILE) from template"; \
	fi
	@$${EDITOR:-nano} $(CONFIG_FILE)
