#!/bin/bash
# =============================================================================
# download-model.sh - Download GGUF models from HuggingFace Hub
# =============================================================================
# Downloads the Llama 4 Scout 17B-16E Instruct model in GGUF Q8_0 format.
#
# Default: Q8_0 (8-bit quantization)
#   - ~58GB file size
#   - Near-lossless quality (virtually indistinguishable from FP16)
#   - Good balance for larger-than-RAM inference
#
# Alternative versions can be configured in config.env:
#   - f16:    ~109GB, full precision (largest, highest quality)
#   - Q4_K_M: ~35GB, good quality/size balance
#   - Q3_K_M: ~25GB, acceptable quality, smaller size
#
# Model Details:
#   - Original: meta-llama/Llama-4-Scout-17B-16E-Instruct
#   - GGUF versions available from various community quantizers
# =============================================================================

set -e

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
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MODELS_DIR="$PROJECT_DIR/models"

# Load user configuration if exists
if [[ -f "$PROJECT_DIR/config.env" ]]; then
    source "$PROJECT_DIR/config.env"
fi

# Default model settings (can be overridden in config.env)
# Note: The actual GGUF repository will depend on community quantizations
# Using Q8_0 (8-bit) as default for near-lossless quality with reasonable size
HF_REPO="${HF_REPO:-unsloth/Llama-4-Scout-17B-16E-Instruct-GGUF}"
MODEL_FILE="${MODEL_FILE:-Llama-4-Scout-17B-16E-Instruct-Q8_0.gguf}"

echo ""
echo "=========================================="
echo "  GGUF Model Downloader"
echo "=========================================="
echo ""

# -----------------------------------------------------------------------------
# Pre-flight checks
# -----------------------------------------------------------------------------
print_step "Checking prerequisites..."

# Check for uv and huggingface-cli
if ! command -v uv &> /dev/null; then
    print_error "uv not found"
    echo "  Run 'make setup' first to install dependencies"
    exit 1
fi

# Verify huggingface-cli is available via uv
if ! uv run huggingface-cli --help &> /dev/null; then
    print_error "huggingface-cli not found in uv environment"
    echo "  Run 'make setup' first to install dependencies"
    exit 1
fi

HF_CLI="uv run huggingface-cli"

print_success "HuggingFace CLI available"

# Check disk space (need at least 70GB free for Q8_0)
AVAILABLE_SPACE_GB=$(df -g "$MODELS_DIR" | awk 'NR==2 {print $4}')
REQUIRED_SPACE_GB=70

if [[ "$AVAILABLE_SPACE_GB" -lt "$REQUIRED_SPACE_GB" ]]; then
    print_error "Insufficient disk space"
    echo "  Available: ${AVAILABLE_SPACE_GB}GB"
    echo "  Required:  ~${REQUIRED_SPACE_GB}GB for Q8_0 model"
    echo ""
    echo "  Tip: Use a smaller quantized version in config.env:"
    echo "    MODEL_FILE=Llama-4-Scout-17B-16E-Instruct-Q4_K_M.gguf  (~35GB)"
    exit 1
fi

print_success "Disk space OK (${AVAILABLE_SPACE_GB}GB available)"

# Create models directory
mkdir -p "$MODELS_DIR"

# -----------------------------------------------------------------------------
# Check HuggingFace authentication
# -----------------------------------------------------------------------------
print_step "Checking HuggingFace authentication..."

# Check if already logged in
if $HF_CLI whoami &> /dev/null; then
    HF_USER=$($HF_CLI whoami 2>/dev/null | head -1)
    print_success "Logged in as: $HF_USER"
else
    print_warning "Not logged in to HuggingFace"
    echo ""
    echo "  Llama 4 models require accepting Meta's license agreement."
    echo "  Please:"
    echo "    1. Create account at https://huggingface.co"
    echo "    2. Accept license at https://huggingface.co/meta-llama/Llama-4-Scout-17B-16E-Instruct"
    echo "    3. Create access token at https://huggingface.co/settings/tokens"
    echo "    4. Run: huggingface-cli login"
    echo ""
    read -p "Press Enter after completing these steps, or Ctrl+C to cancel..."
    
    $HF_CLI login
fi

# -----------------------------------------------------------------------------
# Download model
# -----------------------------------------------------------------------------
echo ""
print_step "Downloading model..."
echo "  Repository: $HF_REPO"
echo "  File:       $MODEL_FILE"
echo "  Destination: $MODELS_DIR"
echo ""

# Check if model already exists
MODEL_PATH="$MODELS_DIR/$MODEL_FILE"
if [[ -f "$MODEL_PATH" ]]; then
    print_warning "Model file already exists: $MODEL_PATH"
    read -p "Re-download? (y/N): " REDOWNLOAD
    if [[ "$REDOWNLOAD" != "y" && "$REDOWNLOAD" != "Y" ]]; then
        print_success "Using existing model file"
        exit 0
    fi
fi

# Download using huggingface-cli
print_step "Starting download (this may take a while for large models)..."
echo ""

# Attempt download with user-friendly error handling
if ! $HF_CLI download "$HF_REPO" "$MODEL_FILE" \
    --local-dir "$MODELS_DIR" \
    --local-dir-use-symlinks False 2>&1; then
    
    echo ""
    print_error "Download failed!"
    echo ""
    echo "  ┌─────────────────────────────────────────────────────────────────┐"
    echo "  │  ${YELLOW}Repository Not Found?${NC} The GGUF repo may not exist yet.       │"
    echo "  │                                                                 │"
    echo "  │  ${BLUE}To fix this, edit your config.env file:${NC}                       │"
    echo "  │                                                                 │"
    echo "  │    1. Open: ${GREEN}./config.env${NC}                                        │"
    echo "  │    2. Update ${GREEN}HF_REPO${NC} to a valid GGUF repository               │"
    echo "  │    3. Update ${GREEN}MODEL_FILE${NC} to match an available file            │"
    echo "  │    4. Re-run: ${GREEN}make download${NC}                                    │"
    echo "  │                                                                 │"
    echo "  │  ${BLUE}How to find a valid repository:${NC}                                │"
    echo "  │    • Search: https://huggingface.co/models?search=llama-4+gguf │"
    echo "  │    • Check the 'Files' tab for available .gguf files           │"
    echo "  │                                                                 │"
    echo "  │  ${BLUE}Popular GGUF quantizers to check:${NC}                              │"
    echo "  │    • https://huggingface.co/unsloth                            │"
    echo "  │    • https://huggingface.co/lmstudio-community                 │"
    echo "  │    • https://huggingface.co/bartowski                          │"
    echo "  │                                                                 │"
    echo "  │  ${BLUE}Current config:${NC}                                                │"
    echo "  │    HF_REPO:    $HF_REPO"
    echo "  │    MODEL_FILE: $MODEL_FILE"
    echo "  │                                                                 │"
    echo "  │  ${YELLOW}See docs/TROUBLESHOOTING.md for more help${NC}                     │"
    echo "  └─────────────────────────────────────────────────────────────────┘"
    echo ""
    exit 1
fi

# Verify download
if [[ -f "$MODEL_PATH" ]]; then
    FILE_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
    print_success "Download complete!"
    echo ""
    echo "  File: $MODEL_PATH"
    echo "  Size: $FILE_SIZE"
else
    # Check if file ended up in a subdirectory (HF CLI behavior)
    FOUND_MODEL=$(find "$MODELS_DIR" -name "$MODEL_FILE" -type f 2>/dev/null | head -1)
    if [[ -n "$FOUND_MODEL" ]]; then
        print_success "Download complete!"
        echo ""
        echo "  File: $FOUND_MODEL"
        
        # Move to expected location if in subdirectory
        if [[ "$FOUND_MODEL" != "$MODEL_PATH" ]]; then
            mv "$FOUND_MODEL" "$MODEL_PATH"
            print_success "Moved to: $MODEL_PATH"
        fi
    else
        print_error "Download may have failed - model file not found"
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Update config with model path
# -----------------------------------------------------------------------------
CONFIG_FILE="$PROJECT_DIR/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    # Update MODEL_PATH in config if it exists
    if grep -q "^MODEL_PATH=" "$CONFIG_FILE"; then
        sed -i '' "s|^MODEL_PATH=.*|MODEL_PATH=$MODEL_PATH|" "$CONFIG_FILE"
    else
        echo "MODEL_PATH=$MODEL_PATH" >> "$CONFIG_FILE"
    fi
    print_success "Updated config.env with model path"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  Download Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Start chatting:  make chat"
echo "  2. Start server:    make serve"
echo ""
print_warning "First run may be slow as the model loads into memory"
echo ""
