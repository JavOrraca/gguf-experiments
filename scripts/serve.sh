#!/bin/bash
# =============================================================================
# serve.sh - OpenAI-compatible API server for larger-than-RAM LLMs
# =============================================================================
# Starts an HTTP server that exposes an OpenAI-compatible API.
# This allows you to use the model with any OpenAI client library.
#
# Endpoints:
#   POST /v1/chat/completions  - Chat completion (like ChatGPT)
#   POST /v1/completions       - Text completion
#   GET  /v1/models            - List available models
#   GET  /health               - Health check
#
# Usage:
#   ./scripts/serve.sh              # Start server on default port
#   ./scripts/serve.sh --port 9000  # Start on custom port
#   make serve                      # Via Makefile
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
# Defaults (optimized for larger-than-RAM inference)
MODEL_PATH="$PROJECT_DIR/models/Llama-4-Scout-17B-16E-Instruct-Q8_0.gguf"
CONTEXT_SIZE=2048
THREADS="auto"
BATCH_SIZE=256
GPU_LAYERS=0
USE_MMAP=true
USE_MLOCK=false
KV_CACHE_TYPE_K="q8_0"
KV_CACHE_TYPE_V="q8_0"
SERVER_HOST="127.0.0.1"
SERVER_PORT=8080
SERVER_VERBOSE=false
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
    echo "OpenAI-Compatible API Server - Larger-than-RAM LLM"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  --port PORT      Override server port (default: $SERVER_PORT)"
    echo "  --host HOST      Override server host (default: $SERVER_HOST)"
    echo "  --verbose        Enable verbose logging"
    echo "  --cpu-only       Force CPU-only mode (no GPU/Metal)"
    echo ""
    echo "API Endpoints:"
    echo "  POST /v1/chat/completions  Chat completion"
    echo "  POST /v1/completions       Text completion"
    echo "  GET  /v1/models            List models"
    echo "  GET  /health               Health check"
    echo ""
    echo "Example API call:"
    echo "  curl http://localhost:$SERVER_PORT/v1/chat/completions \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{"
    echo '      "model": "llama-4-scout",'
    echo '      "messages": [{"role": "user", "content": "Hello!"}]'
    echo "    }'"
    echo ""
    exit 0
fi

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            SERVER_PORT="$2"
            shift 2
            ;;
        --host)
            SERVER_HOST="$2"
            shift 2
            ;;
        --verbose)
            SERVER_VERBOSE=true
            shift
            ;;
        --cpu-only)
            GPU_LAYERS=0
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Verify prerequisites
# -----------------------------------------------------------------------------
print_step "Checking prerequisites..."

# Check for llama-server
if ! command -v llama-server &> /dev/null; then
    print_error "llama-server not found"
    echo "  Run 'make setup' first to install llama.cpp"
    exit 1
fi

print_success "llama-server found"

# Check for model file
if [[ ! -f "$MODEL_PATH" ]]; then
    print_error "Model not found: $MODEL_PATH"
    echo "  Run 'make download' first to download the model"
    exit 1
fi

MODEL_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
print_success "Model found: $(basename "$MODEL_PATH") ($MODEL_SIZE)"

# Check if port is already in use
if lsof -Pi :$SERVER_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    print_error "Port $SERVER_PORT is already in use"
    echo "  Stop the existing server with 'make stop' or use --port to specify another port"
    exit 1
fi

# -----------------------------------------------------------------------------
# Build llama-server command
# -----------------------------------------------------------------------------
CMD=(llama-server)

# Model file
CMD+=(--model "$MODEL_PATH")

# Server settings
CMD+=(--host "$SERVER_HOST")
CMD+=(--port "$SERVER_PORT")

# Context settings
CMD+=(--ctx-size "$CONTEXT_SIZE")

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
# Only add --mlock if explicitly enabled; omitting it means no memory locking
if [[ "$USE_MLOCK" == "true" ]]; then
    CMD+=(--mlock)
fi

# KV cache quantization - reduces memory usage significantly
# q8_0 = 50% less memory, q4_0 = 75% less memory vs f16 default
if [[ -n "$KV_CACHE_TYPE_K" ]]; then
    CMD+=(--cache-type-k "$KV_CACHE_TYPE_K")
fi
if [[ -n "$KV_CACHE_TYPE_V" ]]; then
    CMD+=(--cache-type-v "$KV_CACHE_TYPE_V")
fi

# Flash attention (requires value: on, off, or auto)
if [[ "$FLASH_ATTENTION" == "true" ]]; then
    CMD+=(--flash-attn on)
fi

# Verbose logging
if [[ "$SERVER_VERBOSE" == "true" ]]; then
    CMD+=(--verbose)
fi

# Enable chat completions endpoint
CMD+=(--chat-template llama3)

# -----------------------------------------------------------------------------
# Start server
# -----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  OpenAI-Compatible API Server"
echo "=========================================="
echo ""
echo "Model:       $(basename "$MODEL_PATH")"
echo "Context:     $CONTEXT_SIZE tokens"
echo "GPU Layers:  $GPU_LAYERS"
echo "KV Cache:    $KV_CACHE_TYPE_K / $KV_CACHE_TYPE_V"
echo "Memory Map:  $USE_MMAP"
echo ""
echo "Server URL:  http://$SERVER_HOST:$SERVER_PORT"
echo ""
echo "------------------------------------------"
echo ""
print_step "Starting server..."
echo ""
print_success "Server starting on http://$SERVER_HOST:$SERVER_PORT"
echo ""
echo "API Endpoints:"
echo "  • Chat:   POST http://$SERVER_HOST:$SERVER_PORT/v1/chat/completions"
echo "  • Health: GET  http://$SERVER_HOST:$SERVER_PORT/health"
echo ""
print_warning "Press Ctrl+C to stop the server"
echo ""
echo "------------------------------------------"
echo ""

# Run the server
exec "${CMD[@]}"
