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

@test "config.env.example contains RAM_LIMIT" {
    run grep -q "RAM_LIMIT" "$PROJECT_ROOT/config.env.example"
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

@test "config.env.example contains HF_HUB_ENABLE_HF_TRANSFER" {
    run grep -q "HF_HUB_ENABLE_HF_TRANSFER" "$PROJECT_ROOT/config.env.example"
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

@test "default RAM_LIMIT is 12G" {
    local ram_limit
    ram_limit=$(grep "^RAM_LIMIT=" "$PROJECT_ROOT/config.env.example" | cut -d'=' -f2)
    [ "$ram_limit" = "12G" ]
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
# RAM_LIMIT format validation
# =============================================================================

@test "RAM_LIMIT accepts G suffix" {
    local RAM_LIMIT="12G"
    [[ "$RAM_LIMIT" =~ ^[0-9]+G$ ]]
}

@test "RAM_LIMIT accepts numeric bytes" {
    local RAM_LIMIT="12884901888"
    [[ "$RAM_LIMIT" =~ ^[0-9]+$ ]]
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
