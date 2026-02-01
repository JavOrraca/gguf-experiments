# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GGUF Experiments is a CLI framework for running large language models (17B+ parameters) that exceed available RAM on macOS using memory-mapped inference. It enables running models like Llama 4 Scout on consumer hardware by memory-mapping model files instead of loading them entirely into RAM.

**Platform:** macOS only (CPU-only by default; GPU acceleration available on Apple Silicon)

## Common Commands

```bash
# Setup & Installation
make setup              # Install llama.cpp, uv, Python 3.13 + dependencies
make download           # Download Llama 4 Scout GGUF (~115GB Q8_0)

# Running Models
make chat               # Interactive chat session
make query PROMPT="..." # Single inference query
make serve              # Start OpenAI-compatible API server (port 8080)
make stop               # Stop API server

# Development
make test               # Run BATS unit tests
make test-inference     # Quick inference test
make lint               # Check shell scripts with shellcheck
make info               # Show system info and model status
make config             # Open config.env in editor
```

## Architecture

```
scripts/
├── setup.sh           # Installs llama.cpp (Homebrew), uv, Python 3.13 + hf CLI
├── download-model.sh  # Downloads GGUF from HuggingFace (uses hf CLI + hf_transfer)
├── chat.sh            # Interactive chat via llama-cli
├── query.sh           # Single prompt execution via llama-cli
└── serve.sh           # Starts llama-server for OpenAI-compatible API

tests/                 # BATS test files (*.bats)
docs/
├── CONCEPTS.md        # Deep dive on mmap, quantization, GGUF format
└── TROUBLESHOOTING.md # Common issues and solutions
models/                # Downloaded GGUF files (gitignored)
```

All inference is handled by `llama.cpp` (installed via Homebrew). Scripts are Bash and configuration is via environment variables in `config.env`.

## Configuration

Copy `config.env.example` to `config.env`. Critical settings for larger-than-RAM operation:

| Setting | Purpose |
|---------|---------|
| `USE_MMAP=true` | **Required** - enables memory-mapped inference |
| `USE_MLOCK=false` | **Required** - allows OS to swap model pages |
| `KV_CACHE_TYPE_K=q8_0` | Quantized KV cache (50% less memory than default) |
| `KV_CACHE_TYPE_V=q8_0` | Quantized KV cache for values |
| `CONTEXT_SIZE=2048` | Smaller context = less KV cache memory |
| `MODEL_QUANT` | Quantization level (Q8_0, Q6_K, Q4_K_M, etc.) |

**Note:** There is no setting to hard-limit total RAM. The OS manages memory via mmap paging.

## Testing

Tests use BATS (Bash Automated Testing System):
```bash
brew install bats-core  # Install test framework
make test               # Run all tests in tests/*.bats
```
