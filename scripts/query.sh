#!/bin/bash
# =============================================================================
# query.sh - Single-shot query for scripting and pipelines
# =============================================================================
# Run a single prompt and get a response. Useful for:
#   - Shell scripts
#   - Data pipelines
#   - Automation
#   - Testing
#
# Usage:
#   ./scripts/query.sh "What is the capital of France?"
#   echo "Summarize this text: ..." | ./scripts/query.sh
#   make query PROMPT="your question here"
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output (only used for stderr)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1" >&2
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
    echo "Single Query - Larger-than-RAM LLM Inference"
    echo ""
    echo "Usage: $0 \"your prompt here\""
    echo "       echo \"your prompt\" | $0"
    echo ""
    echo "Options:"
    echo "  -h, --help         Show this help message"
    echo "  --system \"...\"     Override system prompt"
    echo "  --max-tokens N     Override max tokens (default: $MAX_TOKENS)"
    echo "  --temp N           Override temperature (default: $TEMPERATURE)"
    echo "  --json             Request JSON output"
    echo ""
    echo "Examples:"
    echo "  $0 \"What is 2+2?\""
    echo "  $0 --max-tokens 100 \"Write a haiku about coding\""
    echo "  cat article.txt | $0 \"Summarize this article:\""
    echo ""
    exit 0
fi

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
PROMPT=""
JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --system)
            SYSTEM_PROMPT="$2"
            shift 2
            ;;
        --max-tokens)
            MAX_TOKENS="$2"
            shift 2
            ;;
        --temp)
            TEMPERATURE="$2"
            shift 2
            ;;
        --json)
            JSON_MODE=true
            shift
            ;;
        --cpu-only)
            GPU_LAYERS=0
            shift
            ;;
        *)
            # Assume it's the prompt
            PROMPT="$1"
            shift
            ;;
    esac
done

# Read from stdin if no prompt provided
if [[ -z "$PROMPT" ]]; then
    if [[ -t 0 ]]; then
        print_error "No prompt provided"
        echo "Usage: $0 \"your prompt here\"" >&2
        exit 1
    else
        # Read from stdin
        STDIN_CONTENT=$(cat)
        PROMPT="$STDIN_CONTENT"
    fi
fi

# -----------------------------------------------------------------------------
# Verify prerequisites
# -----------------------------------------------------------------------------

# Check for llama-cli
if ! command -v llama-cli &> /dev/null; then
    print_error "llama-cli not found"
    echo "  Run 'make setup' first to install llama.cpp" >&2
    exit 1
fi

# Check for model file
if [[ ! -f "$MODEL_PATH" ]]; then
    print_error "Model not found: $MODEL_PATH"
    echo "  Run 'make download' first to download the model" >&2
    exit 1
fi

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

# Non-interactive mode
CMD+=(--no-display-prompt)

# JSON mode if requested
if [[ "$JSON_MODE" == "true" ]]; then
    SYSTEM_PROMPT="$SYSTEM_PROMPT. Always respond with valid JSON."
fi

# Build the full prompt with system prompt
if [[ -n "$SYSTEM_PROMPT" ]]; then
    FULL_PROMPT="<|system|>
$SYSTEM_PROMPT
<|user|>
$PROMPT
<|assistant|>"
else
    FULL_PROMPT="<|user|>
$PROMPT
<|assistant|>"
fi

# Add prompt
CMD+=(--prompt "$FULL_PROMPT")

# -----------------------------------------------------------------------------
# Run inference
# -----------------------------------------------------------------------------
print_warning "Running inference..." >&2

# Run llama-cli and output only the response to stdout
"${CMD[@]}" 2>/dev/null
