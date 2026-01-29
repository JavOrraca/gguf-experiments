#!/bin/bash
# =============================================================================
# chat.sh - Interactive chat with larger-than-RAM LLMs
# =============================================================================
# Starts an interactive chat session using llama-cli with memory-mapped
# inference for models that exceed available RAM.
#
# Usage:
#   ./scripts/chat.sh              # Use config.env settings
#   ./scripts/chat.sh --help       # Show help
#
# The key to larger-than-RAM operation is the --mmap flag, which tells
# llama.cpp to memory-map the model file. This means:
#   - Only the parts of the model needed RIGHT NOW are loaded into RAM
#   - The OS manages paging data in/out as needed
#   - Inference is slower but WORKS even with insufficient RAM
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# -----------------------------------------------------------------------------
# Load configuration
# -----------------------------------------------------------------------------
# Defaults
MODEL_PATH="$PROJECT_DIR/models/Llama-4-Scout-17B-16E-Instruct-Q8_0.gguf"
CONTEXT_SIZE=4096
MAX_TOKENS=2048
TEMPERATURE=0.7
THREADS="auto"
BATCH_SIZE=512
GPU_LAYERS=999
USE_MMAP=true
USE_MLOCK=false
SYSTEM_PROMPT="You are a helpful AI assistant. Be concise and accurate."
REPEAT_PENALTY=1.1
TOP_K=40
TOP_P=0.95
FLASH_ATTENTION=true

# Load user config if exists
if [[ -f "$PROJECT_DIR/config.env" ]]; then
    source "$PROJECT_DIR/config.env"
fi

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo ""
    echo "Interactive Chat - Larger-than-RAM LLM Inference"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --cpu-only     Force CPU-only mode (no GPU/Metal)"
    echo ""
    echo "Configuration is loaded from config.env"
    echo "Edit config.env to change settings like RAM_LIMIT, CONTEXT_SIZE, etc."
    echo ""
    exit 0
fi

# Handle --cpu-only flag
if [[ "$1" == "--cpu-only" ]]; then
    GPU_LAYERS=0
    print_warning "Running in CPU-only mode"
fi

# -----------------------------------------------------------------------------
# Verify prerequisites
# -----------------------------------------------------------------------------
print_step "Checking prerequisites..."

# Check for llama-cli
if ! command -v llama-cli &> /dev/null; then
    print_error "llama-cli not found"
    echo "  Run 'make setup' first to install llama.cpp"
    exit 1
fi

# Check for model file
if [[ ! -f "$MODEL_PATH" ]]; then
    print_error "Model not found: $MODEL_PATH"
    echo "  Run 'make download' first to download the model"
    exit 1
fi

MODEL_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
print_success "Model found: $MODEL_PATH ($MODEL_SIZE)"

# -----------------------------------------------------------------------------
# Build llama-cli command
# -----------------------------------------------------------------------------
CMD=(llama-cli)

# Model file
CMD+=(--model "$MODEL_PATH")

# Context and generation settings
CMD+=(--ctx-size "$CONTEXT_SIZE")
CMD+=(--predict "$MAX_TOKENS")
CMD+=(--temp "$TEMPERATURE")

# Batch size
CMD+=(--batch-size "$BATCH_SIZE")

# Threading
if [[ "$THREADS" != "auto" ]]; then
    CMD+=(--threads "$THREADS")
fi

# GPU layers (Metal on Apple Silicon)
CMD+=(--n-gpu-layers "$GPU_LAYERS")

# Memory mapping - THE KEY FOR LARGER-THAN-RAM!
if [[ "$USE_MMAP" == "true" ]]; then
    CMD+=(--mmap)
fi

# Memory locking (disable for larger-than-RAM)
if [[ "$USE_MLOCK" == "true" ]]; then
    CMD+=(--mlock)
else
    CMD+=(--no-mmap-lock)
fi

# Sampling parameters
CMD+=(--repeat-penalty "$REPEAT_PENALTY")
CMD+=(--top-k "$TOP_K")
CMD+=(--top-p "$TOP_P")

# Flash attention
if [[ "$FLASH_ATTENTION" == "true" ]]; then
    CMD+=(--flash-attn)
fi

# Interactive mode with conversation
CMD+=(--interactive)
CMD+=(--conversation)
CMD+=(--color)

# System prompt
if [[ -n "$SYSTEM_PROMPT" ]]; then
    CMD+=(--system-prompt "$SYSTEM_PROMPT")
fi

# -----------------------------------------------------------------------------
# Start chat
# -----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  Larger-than-RAM LLM Chat"
echo "=========================================="
echo ""
echo "Model:       $(basename "$MODEL_PATH")"
echo "Context:     $CONTEXT_SIZE tokens"
echo "GPU Layers:  $GPU_LAYERS"
echo "Memory Map:  $USE_MMAP"
echo ""
print_warning "First response may be slow while model loads"
print_warning "Type 'quit' or press Ctrl+C to exit"
echo ""
echo "------------------------------------------"
echo ""

# Run llama-cli
exec "${CMD[@]}"
