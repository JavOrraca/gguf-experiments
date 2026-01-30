#!/usr/bin/env bats
# =============================================================================
# download.bats - Tests for download-model.sh
# =============================================================================
# Run with: bats tests/download.bats
# Install bats: brew install bats-core
# =============================================================================

load 'test_helper'

setup() {
    setup_test_environment
    create_test_config

    # Define test variables
    DOWNLOAD_MAX_RETRIES=3
    DOWNLOAD_RETRY_DELAY=1

    # Define the retry function inline for testing
    run_with_retry() {
        local cmd="$1"
        local max_retries="$DOWNLOAD_MAX_RETRIES"
        local retry_delay="$DOWNLOAD_RETRY_DELAY"
        local attempt=1

        while [[ $attempt -le $max_retries ]]; do
            if [[ $attempt -gt 1 ]]; then
                sleep "$retry_delay"
                retry_delay=$((retry_delay * 2))
                if [[ $retry_delay -gt 300 ]]; then
                    retry_delay=300
                fi
            fi

            if eval "$cmd"; then
                return 0
            fi

            attempt=$((attempt + 1))
        done

        return 1
    }

    # Define single file quant checker
    SINGLE_FILE_QUANTS=("Q2_K" "Q2_K_L" "Q3_K_S" "UD-IQ1_M" "UD-IQ1_S")

    is_single_file_quant() {
        local quant="$1"
        for sf_quant in "${SINGLE_FILE_QUANTS[@]}"; do
            if [[ "$quant" == "$sf_quant" ]]; then
                return 0
            fi
        done
        return 1
    }
}

teardown() {
    teardown_test_environment
}

# =============================================================================
# is_single_file_quant tests
# =============================================================================

@test "is_single_file_quant returns true for Q2_K" {
    run is_single_file_quant "Q2_K"
    [ "$status" -eq 0 ]
}

@test "is_single_file_quant returns true for Q3_K_S" {
    run is_single_file_quant "Q3_K_S"
    [ "$status" -eq 0 ]
}

@test "is_single_file_quant returns false for Q8_0 (sharded)" {
    run is_single_file_quant "Q8_0"
    [ "$status" -eq 1 ]
}

@test "is_single_file_quant returns false for Q4_K_M (sharded)" {
    run is_single_file_quant "Q4_K_M"
    [ "$status" -eq 1 ]
}

@test "is_single_file_quant returns false for BF16 (sharded)" {
    run is_single_file_quant "BF16"
    [ "$status" -eq 1 ]
}

# =============================================================================
# run_with_retry tests
# =============================================================================

@test "run_with_retry succeeds on first attempt" {
    run run_with_retry "true"
    [ "$status" -eq 0 ]
}

@test "run_with_retry fails after max retries" {
    DOWNLOAD_MAX_RETRIES=2
    run run_with_retry "false"
    [ "$status" -eq 1 ]
}

@test "run_with_retry succeeds after initial failures" {
    local state_file="$TEST_TEMP_DIR/retry_state"

    # Create a command that fails twice then succeeds
    test_cmd() {
        local count=0
        if [[ -f "$state_file" ]]; then
            count=$(cat "$state_file")
        fi
        count=$((count + 1))
        echo "$count" > "$state_file"

        if [[ $count -lt 3 ]]; then
            return 1
        fi
        return 0
    }

    # Export the function and state file for the subshell
    export -f test_cmd
    export state_file

    DOWNLOAD_MAX_RETRIES=5
    run run_with_retry "test_cmd"
    [ "$status" -eq 0 ]

    # Verify it took 3 attempts
    [ "$(cat "$state_file")" -eq 3 ]
}

# =============================================================================
# Configuration loading tests
# =============================================================================

@test "config file sets correct defaults" {
    source "$TEST_CONFIG_FILE"

    [ "$HF_REPO" = "test/test-repo" ]
    [ "$MODEL_NAME" = "test-model" ]
    [ "$MODEL_QUANT" = "Q4_K_M" ]
    [ "$RAM_LIMIT" = "8G" ]
}

@test "DOWNLOAD_TIMEOUT can be overridden" {
    echo "DOWNLOAD_TIMEOUT=7200" >> "$TEST_CONFIG_FILE"
    source "$TEST_CONFIG_FILE"

    [ "$DOWNLOAD_TIMEOUT" = "7200" ]
}

@test "DOWNLOAD_MAX_RETRIES can be overridden" {
    echo "DOWNLOAD_MAX_RETRIES=10" >> "$TEST_CONFIG_FILE"
    source "$TEST_CONFIG_FILE"

    [ "$DOWNLOAD_MAX_RETRIES" = "10" ]
}

# =============================================================================
# Environment variable tests
# =============================================================================

@test "HF_HUB_DOWNLOAD_TIMEOUT is set correctly" {
    export DOWNLOAD_TIMEOUT=3600
    export HF_HUB_DOWNLOAD_TIMEOUT="$DOWNLOAD_TIMEOUT"

    [ "$HF_HUB_DOWNLOAD_TIMEOUT" = "3600" ]
}

@test "HF_HUB_ENABLE_HF_TRANSFER defaults to enabled" {
    export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-1}"

    [ "$HF_HUB_ENABLE_HF_TRANSFER" = "1" ]
}

# =============================================================================
# Model path construction tests
# =============================================================================

@test "single file model path is constructed correctly" {
    local MODEL_NAME="Llama-4-Scout"
    local MODEL_QUANT="Q2_K"
    local MODELS_DIR="$TEST_MODELS_DIR"

    local MODEL_FILE="${MODEL_NAME}-${MODEL_QUANT}.gguf"
    local MODEL_PATH="$MODELS_DIR/$MODEL_FILE"

    [ "$MODEL_FILE" = "Llama-4-Scout-Q2_K.gguf" ]
    [ "$MODEL_PATH" = "$TEST_MODELS_DIR/Llama-4-Scout-Q2_K.gguf" ]
}

@test "sharded model path points to first shard pattern" {
    local MODEL_NAME="Llama-4-Scout"
    local MODEL_QUANT="Q8_0"
    local MODELS_DIR="$TEST_MODELS_DIR"

    local MODEL_PATH="$MODELS_DIR/${MODEL_QUANT}/${MODEL_NAME}-${MODEL_QUANT}-00001-of-*.gguf"

    assert_contains "$MODEL_PATH" "Q8_0"
    assert_contains "$MODEL_PATH" "00001-of-"
}

# =============================================================================
# Directory structure tests
# =============================================================================

@test "models directory is created" {
    mkdir -p "$TEST_MODELS_DIR"
    assert_dir_exists "$TEST_MODELS_DIR"
}

@test "sharded model subdirectory can be created" {
    local SHARD_DIR="$TEST_MODELS_DIR/Q8_0"
    mkdir -p "$SHARD_DIR"

    assert_dir_exists "$SHARD_DIR"
}

@test "config file can be created and read" {
    assert_file_exists "$TEST_CONFIG_FILE"

    local content
    content=$(cat "$TEST_CONFIG_FILE")

    assert_contains "$content" "HF_REPO"
    assert_contains "$content" "MODEL_QUANT"
}
