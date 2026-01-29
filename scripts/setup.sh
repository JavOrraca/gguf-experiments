#!/bin/bash
# =============================================================================
# setup.sh - Install dependencies for larger-than-RAM LLM inference
# =============================================================================
# This script installs:
#   1. Homebrew (if not present)
#   2. llama.cpp - The inference engine for GGUF models
#   3. huggingface-cli - For downloading models from HuggingFace Hub
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

echo ""
echo "=========================================="
echo "  GGUF Experiments - Setup Script"
echo "  Larger-than-RAM LLM Inference on macOS"
echo "=========================================="
echo ""

# -----------------------------------------------------------------------------
# Check for macOS
# -----------------------------------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
    print_error "This script is designed for macOS only."
    print_warning "For Linux, you'll need to adapt the installation commands."
    exit 1
fi

print_success "Running on macOS"

# -----------------------------------------------------------------------------
# Check/Install Homebrew
# -----------------------------------------------------------------------------
print_step "Checking for Homebrew..."

if ! command -v brew &> /dev/null; then
    print_warning "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    print_success "Homebrew is installed"
fi

# -----------------------------------------------------------------------------
# Install llama.cpp
# -----------------------------------------------------------------------------
print_step "Installing llama.cpp..."

if brew list llama.cpp &> /dev/null; then
    print_success "llama.cpp is already installed"
    print_step "Checking for updates..."
    brew upgrade llama.cpp 2>/dev/null || print_success "llama.cpp is up to date"
else
    brew install llama.cpp
    print_success "llama.cpp installed successfully"
fi

# Verify llama.cpp installation
if command -v llama-cli &> /dev/null; then
    LLAMA_VERSION=$(llama-cli --version 2>&1 | head -1 || echo "unknown")
    print_success "llama-cli available: $LLAMA_VERSION"
else
    print_error "llama-cli not found in PATH"
    print_warning "You may need to restart your terminal or add Homebrew to PATH"
fi

if command -v llama-server &> /dev/null; then
    print_success "llama-server available"
else
    print_warning "llama-server not found - API server may not work"
fi

# -----------------------------------------------------------------------------
# Install Python and huggingface-cli
# -----------------------------------------------------------------------------
print_step "Setting up Python environment for HuggingFace CLI..."

# Check for Python
if ! command -v python3 &> /dev/null; then
    print_warning "Python 3 not found. Installing via Homebrew..."
    brew install python@3.11
fi

PYTHON_VERSION=$(python3 --version)
print_success "Python available: $PYTHON_VERSION"

# Install/upgrade pip
print_step "Ensuring pip is up to date..."
python3 -m pip install --upgrade pip --quiet

# Install huggingface_hub CLI
print_step "Installing HuggingFace Hub CLI..."
python3 -m pip install --upgrade huggingface_hub --quiet

if command -v huggingface-cli &> /dev/null; then
    print_success "huggingface-cli installed successfully"
else
    # Try with python -m
    if python3 -m huggingface_hub.commands.huggingface_cli --help &> /dev/null; then
        print_success "huggingface-cli available via python3 -m"
        print_warning "You may need to add Python scripts to PATH"
    else
        print_error "huggingface-cli installation may have failed"
    fi
fi

# -----------------------------------------------------------------------------
# Create models directory
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MODELS_DIR="$PROJECT_DIR/models"

print_step "Creating models directory..."
mkdir -p "$MODELS_DIR"
print_success "Models directory ready: $MODELS_DIR"

# -----------------------------------------------------------------------------
# Create config.env if it doesn't exist
# -----------------------------------------------------------------------------
CONFIG_FILE="$PROJECT_DIR/config.env"
CONFIG_EXAMPLE="$PROJECT_DIR/config.env.example"

if [[ ! -f "$CONFIG_FILE" ]] && [[ -f "$CONFIG_EXAMPLE" ]]; then
    print_step "Creating config.env from template..."
    cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"
    print_success "Created config.env - edit this file to customize settings"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
print_success "All dependencies installed"
echo ""
echo "Next steps:"
echo "  1. Download a model:  make download"
echo "  2. Start chatting:    make chat"
echo "  3. Or start server:   make serve"
echo ""

# Check available RAM
TOTAL_RAM_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
print_warning "Your system has ${TOTAL_RAM_GB}GB RAM"
echo "  Edit config.env to set RAM_LIMIT (recommended: $(( TOTAL_RAM_GB * 2 / 3 ))G)"
echo ""
