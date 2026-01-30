#!/bin/bash
# =============================================================================
# test_helper.bash - Shared test utilities for bats tests
# =============================================================================
# This file is sourced by bats tests to provide common setup and utilities.
# =============================================================================

# Get the absolute path to the project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"

# Create a temporary directory for test artifacts
setup_test_environment() {
    export TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_MODELS_DIR="$TEST_TEMP_DIR/models"
    export TEST_CONFIG_FILE="$TEST_TEMP_DIR/config.env"
    mkdir -p "$TEST_MODELS_DIR"
}

# Clean up temporary directory
teardown_test_environment() {
    if [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Create a minimal config.env for testing
create_test_config() {
    cat > "$TEST_CONFIG_FILE" << 'EOF'
HF_REPO=test/test-repo
MODEL_NAME=test-model
MODEL_QUANT=Q4_K_M
RAM_LIMIT=8G
USE_MMAP=true
USE_MLOCK=false
CONTEXT_SIZE=2048
MAX_TOKENS=1024
TEMPERATURE=0.7
GPU_LAYERS=0
DOWNLOAD_TIMEOUT=60
DOWNLOAD_MAX_RETRIES=3
DOWNLOAD_RETRY_DELAY=1
EOF
}

# Mock command that always succeeds
mock_success() {
    return 0
}

# Mock command that always fails
mock_failure() {
    return 1
}

# Mock command that fails N times then succeeds
# Usage: mock_fail_then_succeed <fail_count> <state_file>
mock_fail_then_succeed() {
    local fail_count="$1"
    local state_file="$2"

    if [[ ! -f "$state_file" ]]; then
        echo "0" > "$state_file"
    fi

    local current_count
    current_count=$(cat "$state_file")
    current_count=$((current_count + 1))
    echo "$current_count" > "$state_file"

    if [[ $current_count -le $fail_count ]]; then
        return 1
    fi
    return 0
}

# Assert that a string contains a substring
assert_contains() {
    local haystack="$1"
    local needle="$2"
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "Expected '$haystack' to contain '$needle'" >&2
        return 1
    fi
}

# Assert that a file exists
assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "Expected file to exist: $file" >&2
        return 1
    fi
}

# Assert that a directory exists
assert_dir_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "Expected directory to exist: $dir" >&2
        return 1
    fi
}

# Source a script's functions without executing main logic
# This extracts functions by sourcing with modified behavior
source_functions_only() {
    local script="$1"

    # Create a temporary file with the script but exit before main execution
    local temp_script="$TEST_TEMP_DIR/$(basename "$script").functions"

    # Extract just the function definitions (crude but effective)
    sed -n '/^[a-zA-Z_][a-zA-Z0-9_]*()[ ]*{/,/^}/p' "$script" > "$temp_script"

    # Source the functions
    source "$temp_script"
}
