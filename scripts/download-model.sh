#!/bin/bash
# =============================================================================
# download-model.sh - Download GGUF models from HuggingFace Hub
# =============================================================================
# Downloads the Llama 4 Scout 17B-16E Instruct model in GGUF format.
#
# Supports both:
#   - SHARDED models (split across multiple files in subdirectories)
#   - SINGLE-FILE models (one .gguf file at root level)
#
# Default: Q8_0 (8-bit quantization, sharded)
#   - ~58GB total file size (3 shards)
#   - Near-lossless quality (virtually indistinguishable from FP16)
#   - Good balance for larger-than-RAM inference
#
# Alternative versions can be configured in config.env via MODEL_QUANT:
#   - BF16:   ~109GB, bfloat16 precision (largest, highest quality)
#   - Q6_K:   ~45GB, 6-bit (excellent quality)
#   - Q5_K_M: ~40GB, 5-bit (very good quality)
#   - Q4_K_M: ~35GB, 4-bit (good quality/size balance)
#   - Q3_K_S: ~22GB, 3-bit single file (acceptable quality)
#   - Q2_K:   ~18GB, 2-bit single file (smallest, lower quality)
#
# Model Details:
#   - Original: meta-llama/Llama-4-Scout-17B-16E-Instruct
#   - GGUF versions: unsloth/Llama-4-Scout-17B-16E-Instruct-GGUF
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
HF_REPO="${HF_REPO:-unsloth/Llama-4-Scout-17B-16E-Instruct-GGUF}"
MODEL_NAME="${MODEL_NAME:-Llama-4-Scout-17B-16E-Instruct}"
MODEL_QUANT="${MODEL_QUANT:-Q8_0}"

# Download settings (can be overridden in config.env)
DOWNLOAD_TIMEOUT="${DOWNLOAD_TIMEOUT:-3600}"     # Timeout in seconds (60 min default)
DOWNLOAD_MAX_RETRIES="${DOWNLOAD_MAX_RETRIES:-5}" # Max retry attempts
DOWNLOAD_RETRY_DELAY="${DOWNLOAD_RETRY_DELAY:-10}" # Initial retry delay in seconds

# Configure HuggingFace Hub timeouts (in seconds)
export HF_HUB_DOWNLOAD_TIMEOUT="$DOWNLOAD_TIMEOUT"
export HF_HUB_ETAG_TIMEOUT="$DOWNLOAD_TIMEOUT"

# Check if hf_transfer is available in the uv environment
HF_TRANSFER_AVAILABLE=0
if uv run python -c "import hf_transfer" 2>/dev/null; then
    HF_TRANSFER_AVAILABLE=1
fi

# Clear any existing HF_HUB_ENABLE_HF_TRANSFER (e.g., from config.env)
# and only enable if hf_transfer is actually installed (avoids hard failure)
unset HF_HUB_ENABLE_HF_TRANSFER
if [[ "$HF_TRANSFER_AVAILABLE" -eq 1 ]]; then
    export HF_HUB_ENABLE_HF_TRANSFER=1
else
    export HF_HUB_ENABLE_HF_TRANSFER=0
fi

# Known single-file quantizations (at root level, not in subdirectories)
# These don't follow the sharded pattern
SINGLE_FILE_QUANTS=("Q2_K" "Q2_K_L" "Q3_K_S" "UD-IQ1_M" "UD-IQ1_S" "UD-IQ2_M" "UD-IQ2_XXS" "UD-IQ3_XXS" "UD-Q2_K_XL" "UD-Q3_K_XL" "UD-TQ1_0")

# Check if MODEL_QUANT is a single-file quantization
is_single_file_quant() {
    local quant="$1"
    for sf_quant in "${SINGLE_FILE_QUANTS[@]}"; do
        if [[ "$quant" == "$sf_quant" ]]; then
            return 0  # true
        fi
    done
    return 1  # false
}

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
# Use python -m to ensure we use the venv's huggingface_hub, not any system-installed one
if ! uv run python -m huggingface_hub.commands.huggingface_cli --help &> /dev/null; then
    print_error "huggingface-cli not found in uv environment"
    echo "  Run 'make setup' first to install dependencies"
    exit 1
fi

# Use python -m to ensure we use the venv's module, not system huggingface-cli
HF_CLI="uv run python -m huggingface_hub.commands.huggingface_cli"

print_success "HuggingFace CLI available"

# Check disk space (need at least 70GB free for Q8_0)
AVAILABLE_SPACE_GB=$(df -g "$PROJECT_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
REQUIRED_SPACE_GB=70

if [[ -n "$AVAILABLE_SPACE_GB" ]] && [[ "$AVAILABLE_SPACE_GB" -lt "$REQUIRED_SPACE_GB" ]]; then
    print_warning "Low disk space: ${AVAILABLE_SPACE_GB}GB available"
    echo "  Recommended: ~${REQUIRED_SPACE_GB}GB for Q8_0 model"
    echo ""
    echo "  Tip: Use a smaller quantized version in config.env:"
    echo "    MODEL_QUANT=Q4_K_M  (~35GB)"
    echo "    MODEL_QUANT=Q3_K_S  (~22GB, single file)"
    echo ""
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
        exit 1
    fi
else
    print_success "Disk space OK (${AVAILABLE_SPACE_GB:-unknown}GB available)"
fi

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
# Determine download type (sharded vs single file)
# -----------------------------------------------------------------------------
echo ""
print_step "Preparing download..."

if is_single_file_quant "$MODEL_QUANT"; then
    # Single file download
    DOWNLOAD_TYPE="single"
    MODEL_FILE="${MODEL_NAME}-${MODEL_QUANT}.gguf"
    DOWNLOAD_PATTERN="$MODEL_FILE"
    MODEL_PATH="$MODELS_DIR/$MODEL_FILE"
    echo "  Type: Single file"
else
    # Sharded download (directory with multiple parts)
    DOWNLOAD_TYPE="sharded"
    DOWNLOAD_PATTERN="${MODEL_QUANT}/*.gguf"
    # The first shard is what llama.cpp needs to load the model
    MODEL_PATH="$MODELS_DIR/${MODEL_QUANT}/${MODEL_NAME}-${MODEL_QUANT}-00001-of-*.gguf"
    echo "  Type: Sharded (multiple files)"
fi

echo "  Repository: $HF_REPO"
echo "  Quantization: $MODEL_QUANT"
echo "  Pattern: $DOWNLOAD_PATTERN"
echo "  Destination: $MODELS_DIR"
echo ""

# -----------------------------------------------------------------------------
# Check if model already exists
# -----------------------------------------------------------------------------
if [[ "$DOWNLOAD_TYPE" == "single" ]]; then
    if [[ -f "$MODEL_PATH" ]]; then
        print_warning "Model file already exists: $MODEL_PATH"
        read -p "Re-download? (y/N): " REDOWNLOAD
        if [[ "$REDOWNLOAD" != "y" && "$REDOWNLOAD" != "Y" ]]; then
            print_success "Using existing model file"
            exit 0
        fi
    fi
else
    # Check for sharded model directory
    SHARD_DIR="$MODELS_DIR/$MODEL_QUANT"
    if [[ -d "$SHARD_DIR" ]] && [[ -n "$(ls -A "$SHARD_DIR"/*.gguf 2>/dev/null)" ]]; then
        SHARD_COUNT=$(ls -1 "$SHARD_DIR"/*.gguf 2>/dev/null | wc -l | tr -d ' ')
        print_warning "Sharded model directory exists: $SHARD_DIR ($SHARD_COUNT files)"
        read -p "Re-download? (y/N): " REDOWNLOAD
        if [[ "$REDOWNLOAD" != "y" && "$REDOWNLOAD" != "Y" ]]; then
            print_success "Using existing model files"
            # Find the first shard for MODEL_PATH
            FIRST_SHARD=$(ls -1 "$SHARD_DIR"/*.gguf 2>/dev/null | sort | head -1)
            if [[ -n "$FIRST_SHARD" ]]; then
                MODEL_PATH="$FIRST_SHARD"
            fi
            exit 0
        fi
    fi
fi

# -----------------------------------------------------------------------------
# Download model
# -----------------------------------------------------------------------------
print_step "Starting download (this may take a while for large models)..."
echo ""

# Function to run download with retry logic
run_with_retry() {
    local cmd="$1"
    local max_retries="$DOWNLOAD_MAX_RETRIES"
    local retry_delay="$DOWNLOAD_RETRY_DELAY"
    local attempt=1

    while [[ $attempt -le $max_retries ]]; do
        echo ""
        if [[ $attempt -gt 1 ]]; then
            print_warning "Attempt $attempt of $max_retries (waiting ${retry_delay}s before retry)..."
            sleep "$retry_delay"
            # Exponential backoff: double the delay for next attempt (max 5 min)
            retry_delay=$((retry_delay * 2))
            if [[ $retry_delay -gt 300 ]]; then
                retry_delay=300
            fi
        fi

        # Run the download command
        if eval "$cmd"; then
            return 0  # Success
        fi

        print_warning "Download attempt $attempt failed"
        attempt=$((attempt + 1))
    done

    return 1  # All retries exhausted
}

# Function to display helpful error message
show_download_error() {
    echo ""
    print_error "Download failed after $DOWNLOAD_MAX_RETRIES attempts!"
    echo ""
    echo "  ┌─────────────────────────────────────────────────────────────────┐"
    echo "  │  ${YELLOW}Timeout or Connection Issues?${NC}                                  │"
    echo "  │                                                                 │"
    echo "  │  ${BLUE}Try these fixes in config.env:${NC}                                 │"
    echo "  │    DOWNLOAD_TIMEOUT=7200      # Increase to 2 hours            │"
    echo "  │    DOWNLOAD_MAX_RETRIES=10    # More retry attempts            │"
    echo "  │                                                                 │"
    echo "  │  ${BLUE}For faster downloads, install hf_transfer:${NC}                     │"
    echo "  │    uv add hf_transfer                                          │"
    echo "  │                                                                 │"
    echo "  │  ${BLUE}Re-running the download will resume where it left off.${NC}         │"
    echo "  │                                                                 │"
    echo "  ├─────────────────────────────────────────────────────────────────┤"
    echo "  │  ${YELLOW}File or Repository Not Found?${NC}                                  │"
    echo "  │                                                                 │"
    echo "  │  ${BLUE}To fix this, edit your config.env file:${NC}                       │"
    echo "  │                                                                 │"
    echo "  │    1. Open: ${GREEN}./config.env${NC}                                        │"
    echo "  │    2. Update ${GREEN}HF_REPO${NC} to a valid GGUF repository               │"
    echo "  │    3. Update ${GREEN}MODEL_QUANT${NC} to an available quantization         │"
    echo "  │    4. Re-run: ${GREEN}make download${NC}                                    │"
    echo "  │                                                                 │"
    echo "  │  ${BLUE}How to find valid options:${NC}                                     │"
    echo "  │    • Visit: https://huggingface.co/${HF_REPO}/tree/main        │"
    echo "  │    • Look for folders (Q8_0, Q4_K_M) = sharded models          │"
    echo "  │    • Look for .gguf files at root = single-file models         │"
    echo "  │                                                                 │"
    echo "  │  ${BLUE}Current config:${NC}                                                │"
    echo "  │    HF_REPO:     $HF_REPO"
    echo "  │    MODEL_QUANT: $MODEL_QUANT"
    echo "  │    MODEL_NAME:  $MODEL_NAME"
    echo "  │                                                                 │"
    echo "  │  ${YELLOW}See docs/TROUBLESHOOTING.md for more help${NC}                     │"
    echo "  └─────────────────────────────────────────────────────────────────┘"
    echo ""
}

# Show download settings
echo ""
echo "  ${BLUE}Download settings:${NC}"
echo "    Timeout: ${DOWNLOAD_TIMEOUT}s per request"
echo "    Max retries: ${DOWNLOAD_MAX_RETRIES}"
if [[ "$HF_TRANSFER_AVAILABLE" -eq 1 ]]; then
    echo "    hf_transfer: enabled (faster downloads)"
else
    echo "    hf_transfer: not available (using standard download)"
fi
echo ""

# Attempt download based on type with retry logic
if [[ "$DOWNLOAD_TYPE" == "single" ]]; then
    # Single file download
    DOWNLOAD_CMD="$HF_CLI download \"$HF_REPO\" \"$MODEL_FILE\" --local-dir \"$MODELS_DIR\" --local-dir-use-symlinks False"
    if ! run_with_retry "$DOWNLOAD_CMD"; then
        show_download_error
        exit 1
    fi
else
    # Sharded download - download all files matching the pattern in the quantization folder
    DOWNLOAD_CMD="$HF_CLI download \"$HF_REPO\" --include \"${MODEL_QUANT}/*\" --local-dir \"$MODELS_DIR\" --local-dir-use-symlinks False"
    if ! run_with_retry "$DOWNLOAD_CMD"; then
        show_download_error
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Verify download and find model path
# -----------------------------------------------------------------------------
print_step "Verifying download..."

if [[ "$DOWNLOAD_TYPE" == "single" ]]; then
    # Single file verification
    if [[ -f "$MODELS_DIR/$MODEL_FILE" ]]; then
        MODEL_PATH="$MODELS_DIR/$MODEL_FILE"
        FILE_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
        print_success "Download complete!"
        echo ""
        echo "  File: $MODEL_PATH"
        echo "  Size: $FILE_SIZE"
    else
        # Check if file ended up in a subdirectory
        FOUND_MODEL=$(find "$MODELS_DIR" -name "$MODEL_FILE" -type f 2>/dev/null | head -1)
        if [[ -n "$FOUND_MODEL" ]]; then
            MODEL_PATH="$FOUND_MODEL"
            FILE_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
            print_success "Download complete!"
            echo ""
            echo "  File: $MODEL_PATH"
            echo "  Size: $FILE_SIZE"
        else
            print_error "Download may have failed - model file not found"
            exit 1
        fi
    fi
else
    # Sharded verification
    SHARD_DIR="$MODELS_DIR/$MODEL_QUANT"
    if [[ -d "$SHARD_DIR" ]]; then
        SHARD_FILES=$(ls -1 "$SHARD_DIR"/*.gguf 2>/dev/null | sort)
        SHARD_COUNT=$(echo "$SHARD_FILES" | wc -l | tr -d ' ')
        
        if [[ "$SHARD_COUNT" -gt 0 ]]; then
            FIRST_SHARD=$(echo "$SHARD_FILES" | head -1)
            MODEL_PATH="$FIRST_SHARD"
            TOTAL_SIZE=$(du -sh "$SHARD_DIR" | cut -f1)
            
            print_success "Download complete!"
            echo ""
            echo "  Directory: $SHARD_DIR"
            echo "  Shards: $SHARD_COUNT files"
            echo "  Total size: $TOTAL_SIZE"
            echo "  First shard: $(basename "$FIRST_SHARD")"
            echo ""
            echo "  ${BLUE}Note:${NC} llama.cpp will automatically load all shards when you"
            echo "  point it to the first shard file."
        else
            print_error "Download may have failed - no shard files found in $SHARD_DIR"
            exit 1
        fi
    else
        print_error "Download may have failed - shard directory not found: $SHARD_DIR"
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
echo "Model ready at: $MODEL_PATH"
echo ""
echo "Next steps:"
echo "  1. Start chatting:  make chat"
echo "  2. Start server:    make serve"
echo ""
print_warning "First run may be slow as the model loads into memory"
echo ""
