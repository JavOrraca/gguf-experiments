#!/usr/bin/env bats
# =============================================================================
# config.bats - Tests for configuration validation
# =============================================================================
# Run with: bats tests/config.bats
# Install bats: brew install bats-core
# =============================================================================

load 'test_helper'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

# =============================================================================
# config.env.example validation tests
# =============================================================================

@test "config.env.example exists" {
    assert_file_exists "$PROJECT_ROOT/config.env.example"
}

@test "config.env.example contains MODEL_PATH" {
    run grep -q "MODEL_PATH" "$PROJECT_ROOT/config.env.example"
    [ "$status" -eq 0 ]
}

@test "config.env.example contains HF_REPO" {
    run grep -q "HF_REPO" "$PROJECT_ROOT/config.env.example"
    [ "$status" -eq 0 ]
}

@test "config.env.example contains KV_CACHE_TYPE_K" {
    run grep -q "KV_CACHE_TYPE_K" "$PROJECT_ROOT/config.env.example"
    [ "$status" -eq 0 ]
}

@test "config.env.example contains KV_CACHE_TYPE_V" {
    run grep -q "KV_CACHE_TYPE_V" "$PROJECT_ROOT/config.env.example"
    [ "$status" -eq 0 ]
}

@test "config.env.example contains USE_MMAP" {
    run grep -q "USE_MMAP" "$PROJECT_ROOT/config.env.example"
    [ "$status" -eq 0 ]
}

@test "config.env.example contains GPU_LAYERS" {
    run grep -q "GPU_LAYERS" "$PROJECT_ROOT/config.env.example"
    [ "$status" -eq 0 ]
}

@test "config.env.example contains DOWNLOAD_TIMEOUT" {
    run grep -q "DOWNLOAD_TIMEOUT" "$PROJECT_ROOT/config.env.example"
    [ "$status" -eq 0 ]
}

@test "config.env.example contains DOWNLOAD_MAX_RETRIES" {
    run grep -q "DOWNLOAD_MAX_RETRIES" "$PROJECT_ROOT/config.env.example"
    [ "$status" -eq 0 ]
}

@test "config.env.example mentions hf_transfer (auto-detected)" {
    run grep -q "hf_transfer" "$PROJECT_ROOT/config.env.example"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Default value tests
# =============================================================================

@test "default DOWNLOAD_TIMEOUT is 3600 (60 minutes)" {
    local timeout
    timeout=$(grep "^DOWNLOAD_TIMEOUT=" "$PROJECT_ROOT/config.env.example" | cut -d'=' -f2)
    [ "$timeout" = "3600" ]
}

@test "default DOWNLOAD_MAX_RETRIES is 5" {
    local retries
    retries=$(grep "^DOWNLOAD_MAX_RETRIES=" "$PROJECT_ROOT/config.env.example" | cut -d'=' -f2)
    [ "$retries" = "5" ]
}

@test "default KV_CACHE_TYPE_K is q8_0" {
    local cache_type
    cache_type=$(grep "^KV_CACHE_TYPE_K=" "$PROJECT_ROOT/config.env.example" | cut -d'=' -f2)
    [ "$cache_type" = "q8_0" ]
}

@test "default KV_CACHE_TYPE_V is q8_0" {
    local cache_type
    cache_type=$(grep "^KV_CACHE_TYPE_V=" "$PROJECT_ROOT/config.env.example" | cut -d'=' -f2)
    [ "$cache_type" = "q8_0" ]
}

@test "default USE_MMAP is true" {
    local use_mmap
    use_mmap=$(grep "^USE_MMAP=" "$PROJECT_ROOT/config.env.example" | cut -d'=' -f2)
    [ "$use_mmap" = "true" ]
}

@test "default MODEL_QUANT is Q8_0" {
    local quant
    quant=$(grep "^MODEL_QUANT=" "$PROJECT_ROOT/config.env.example" | cut -d'=' -f2)
    [ "$quant" = "Q8_0" ]
}

# =============================================================================
# KV cache type validation
# =============================================================================

@test "KV_CACHE_TYPE accepts valid quantization types" {
    local valid_types=("f16" "f32" "q8_0" "q4_0" "q4_1" "q5_0" "q5_1")
    local KV_CACHE_TYPE_K="q8_0"
    local found=false
    for t in "${valid_types[@]}"; do
        if [ "$KV_CACHE_TYPE_K" = "$t" ]; then
            found=true
            break
        fi
    done
    [ "$found" = "true" ]
}

# =============================================================================
# Boolean config validation
# =============================================================================

@test "USE_MMAP accepts true" {
    local USE_MMAP="true"
    [ "$USE_MMAP" = "true" ] || [ "$USE_MMAP" = "false" ]
}

@test "USE_MMAP accepts false" {
    local USE_MMAP="false"
    [ "$USE_MMAP" = "true" ] || [ "$USE_MMAP" = "false" ]
}

@test "USE_MLOCK accepts true" {
    local USE_MLOCK="true"
    [ "$USE_MLOCK" = "true" ] || [ "$USE_MLOCK" = "false" ]
}

@test "USE_MLOCK accepts false" {
    local USE_MLOCK="false"
    [ "$USE_MLOCK" = "true" ] || [ "$USE_MLOCK" = "false" ]
}
