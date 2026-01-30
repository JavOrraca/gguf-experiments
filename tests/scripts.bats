#!/usr/bin/env bats
# =============================================================================
# scripts.bats - Tests for script files existence and structure
# =============================================================================
# Run with: bats tests/scripts.bats
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
# Script existence tests
# =============================================================================

@test "setup.sh exists" {
    assert_file_exists "$SCRIPTS_DIR/setup.sh"
}

@test "download-model.sh exists" {
    assert_file_exists "$SCRIPTS_DIR/download-model.sh"
}

@test "chat.sh exists" {
    assert_file_exists "$SCRIPTS_DIR/chat.sh"
}

@test "query.sh exists" {
    assert_file_exists "$SCRIPTS_DIR/query.sh"
}

@test "serve.sh exists" {
    assert_file_exists "$SCRIPTS_DIR/serve.sh"
}

# =============================================================================
# Script executability tests
# =============================================================================

@test "setup.sh is executable" {
    [ -x "$SCRIPTS_DIR/setup.sh" ]
}

@test "download-model.sh is executable" {
    [ -x "$SCRIPTS_DIR/download-model.sh" ]
}

@test "chat.sh is executable" {
    [ -x "$SCRIPTS_DIR/chat.sh" ]
}

@test "query.sh is executable" {
    [ -x "$SCRIPTS_DIR/query.sh" ]
}

@test "serve.sh is executable" {
    [ -x "$SCRIPTS_DIR/serve.sh" ]
}

# =============================================================================
# Script shebang tests
# =============================================================================

@test "setup.sh has bash shebang" {
    run head -1 "$SCRIPTS_DIR/setup.sh"
    assert_contains "$output" "#!/bin/bash"
}

@test "download-model.sh has bash shebang" {
    run head -1 "$SCRIPTS_DIR/download-model.sh"
    assert_contains "$output" "#!/bin/bash"
}

@test "chat.sh has bash shebang" {
    run head -1 "$SCRIPTS_DIR/chat.sh"
    assert_contains "$output" "#!/bin/bash"
}

@test "query.sh has bash shebang" {
    run head -1 "$SCRIPTS_DIR/query.sh"
    assert_contains "$output" "#!/bin/bash"
}

@test "serve.sh has bash shebang" {
    run head -1 "$SCRIPTS_DIR/serve.sh"
    assert_contains "$output" "#!/bin/bash"
}

# =============================================================================
# Script uses set -e for error handling
# =============================================================================

@test "setup.sh uses set -e" {
    run grep -q "set -e" "$SCRIPTS_DIR/setup.sh"
    [ "$status" -eq 0 ]
}

@test "download-model.sh uses set -e" {
    run grep -q "set -e" "$SCRIPTS_DIR/download-model.sh"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Script loads config.env
# =============================================================================

@test "download-model.sh loads config.env" {
    run grep -q 'source.*config.env' "$SCRIPTS_DIR/download-model.sh"
    [ "$status" -eq 0 ]
}

@test "chat.sh loads config.env" {
    run grep -q 'source.*config.env' "$SCRIPTS_DIR/chat.sh"
    [ "$status" -eq 0 ]
}

@test "serve.sh loads config.env" {
    run grep -q 'source.*config.env' "$SCRIPTS_DIR/serve.sh"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Makefile tests
# =============================================================================

@test "Makefile exists" {
    assert_file_exists "$PROJECT_ROOT/Makefile"
}

@test "Makefile has setup target" {
    run grep -q "^setup:" "$PROJECT_ROOT/Makefile"
    [ "$status" -eq 0 ]
}

@test "Makefile has download target" {
    run grep -q "^download:" "$PROJECT_ROOT/Makefile"
    [ "$status" -eq 0 ]
}

@test "Makefile has chat target" {
    run grep -q "^chat:" "$PROJECT_ROOT/Makefile"
    [ "$status" -eq 0 ]
}

@test "Makefile has serve target" {
    run grep -q "^serve:" "$PROJECT_ROOT/Makefile"
    [ "$status" -eq 0 ]
}

@test "Makefile has help target" {
    run grep -q "^help:" "$PROJECT_ROOT/Makefile"
    [ "$status" -eq 0 ]
}

@test "Makefile has test target" {
    run grep -q "^test:" "$PROJECT_ROOT/Makefile"
    [ "$status" -eq 0 ]
}

# =============================================================================
# pyproject.toml tests
# =============================================================================

@test "pyproject.toml exists" {
    assert_file_exists "$PROJECT_ROOT/pyproject.toml"
}

@test "pyproject.toml requires Python >= 3.13" {
    run grep -q 'requires-python = ">=3.13"' "$PROJECT_ROOT/pyproject.toml"
    [ "$status" -eq 0 ]
}

@test "pyproject.toml includes huggingface-hub dependency" {
    run grep -q "huggingface-hub" "$PROJECT_ROOT/pyproject.toml"
    [ "$status" -eq 0 ]
}

@test "pyproject.toml includes hf_transfer dependency" {
    run grep -q "hf_transfer" "$PROJECT_ROOT/pyproject.toml"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Documentation tests
# =============================================================================

@test "README.md exists" {
    assert_file_exists "$PROJECT_ROOT/README.md"
}

@test "TROUBLESHOOTING.md exists" {
    assert_file_exists "$PROJECT_ROOT/docs/TROUBLESHOOTING.md"
}

@test "CONCEPTS.md exists" {
    assert_file_exists "$PROJECT_ROOT/docs/CONCEPTS.md"
}

@test "TROUBLESHOOTING.md mentions timeout issues" {
    run grep -q -i "timeout" "$PROJECT_ROOT/docs/TROUBLESHOOTING.md"
    [ "$status" -eq 0 ]
}
