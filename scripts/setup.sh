#!/bin/bash
# =============================================================================
# setup.sh - Install dependencies for larger-than-RAM LLM inference
# =============================================================================
# This script installs:
#   1. Homebrew (if not present)
#   2. llama.cpp - The inference engine for GGUF models
#   3. uv - Fast Python package manager
#   4. Python 3.13 + huggingface-cli (via uv)
#
# Uses uv for fast, reproducible Python dependency management.
# Learn more: https://docs.astral.sh/uv/
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
# Install uv (Fast Python Package Manager)
# -----------------------------------------------------------------------------
print_step "Setting up uv (Python package manager)..."

if ! command -v uv &> /dev/null; then
    print_step "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    
    # Add uv to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"
    
    if command -v uv &> /dev/null; then
        print_success "uv installed successfully"
    else
        print_error "uv installation failed"
        print_warning "Try running: curl -LsSf https://astral.sh/uv/install.sh | sh"
        print_warning "Then restart your terminal"
        exit 1
    fi
else
    print_success "uv is already installed"
    # Check for updates
    UV_VERSION=$(uv --version 2>&1 | head -1)
    print_success "uv version: $UV_VERSION"
fi

# -----------------------------------------------------------------------------
# Setup Python environment with uv
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

print_step "Setting up Python 3.13 environment..."

cd "$PROJECT_DIR"

# Sync dependencies (this creates venv and installs all deps from pyproject.toml)
print_step "Installing Python dependencies..."
uv sync

# Verify installation
if uv run python --version &> /dev/null; then
    PYTHON_VERSION=$(uv run python --version)
    print_success "Python available: $PYTHON_VERSION"
else
    print_error "Python installation failed"
    exit 1
fi

# Verify huggingface-cli
if uv run huggingface-cli --help &> /dev/null; then
    print_success "huggingface-cli installed successfully"
else
    print_error "huggingface-cli installation failed"
    exit 1
fi

# Verify transformers
if uv run python -c "import transformers; print(f'transformers {transformers.__version__}')" &> /dev/null; then
    TRANSFORMERS_VERSION=$(uv run python -c "import transformers; print(transformers.__version__)")
    print_success "transformers installed: v$TRANSFORMERS_VERSION"
else
    print_warning "transformers import check failed (may still work)"
fi

# Verify tokenizers
if uv run python -c "import tokenizers; print(f'tokenizers {tokenizers.__version__}')" &> /dev/null; then
    TOKENIZERS_VERSION=$(uv run python -c "import tokenizers; print(tokenizers.__version__)")
    print_success "tokenizers installed: v$TOKENIZERS_VERSION"
else
    print_warning "tokenizers import check failed (may still work)"
fi

# -----------------------------------------------------------------------------
# Create models directory
# -----------------------------------------------------------------------------
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
echo "Installed components:"
echo "  • llama.cpp (via Homebrew)"
echo "  • Python 3.13 (via uv)"
echo "  • huggingface-hub, transformers, tokenizers (via uv)"
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
