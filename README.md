# GGUF Experiments

> **Run Large Language Models that exceed your RAM on macOS**

A CLI framework for running larger-than-RAM LLMs (like Llama 4 Scout) on consumer hardware using memory-mapped inference. Think of it like how Apache Arrow lazily reads larger-than-RAM Parquet files, or how Dask processes datasets that don't fit in memory.

---

## What This Does

This project allows you to run the **Llama 4 Scout 17B-16E** model (or similar large models) on a MacBook with limited RAM by:

1. **Memory-mapping** the model file instead of loading it entirely into RAM
2. **Quantizing** the model to reduce its size (Q8_0 = 115GB instead of 216GB BF16)
3. **Paging** model layers in/out of RAM as needed during inference

**Result**: Slower inference, but it *works* on hardware that couldn't otherwise run the model.

---

## Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **macOS** | 12.0+ | 14.0+ (Sonoma) |
| **Chip** | Apple M1 | Apple M2/M3/M4 |
| **RAM** | 16GB | 24GB+ |
| **Disk** | 70GB free (SSD) | 120GB+ free (NVMe) |

**Automatically installed by `make setup`:**
- [Homebrew](https://brew.sh) - Package manager for macOS
- [llama.cpp](https://github.com/ggerganov/llama.cpp) - Inference engine for GGUF models
- [uv](https://docs.astral.sh/uv/) - Fast Python package manager
- Python 3.13 with `huggingface-hub` (includes `hf` CLI), `transformers`, `tokenizers`, and `hf_transfer`

> **Warning:** HDD will be painfully slow. This technique relies on fast disk I/O for paging.

---

## Quick Start

### 1. Clone the repository
```bash
git clone https://github.com/JavOrraca/gguf-experiments.git
cd gguf-experiments
```

### 2. Install dependencies

Install `llama.cpp` and the HuggingFace CLI (`hf`).
```bash
make setup
```

### 3. Configure for your system
A prepopulated configuration setup can be found in `config.env.example`. Copy it to create your config:
```bash
cp config.env.example config.env
nano config.env  # Optionally adjust settings like RAM_LIMIT
```

### 4. Download the model
For this project, the default is the **Q8_0** quantization (115 GB, sharded into 3 files) from [unsloth's GGUF repository](https://huggingface.co/unsloth/Llama-4-Scout-17B-16E-Instruct-GGUF). You can change the quantization level in `config.env` via `MODEL_QUANT`.

```bash
make download
```

> **Note**: Requires a HuggingFace account. If you get a "Repository Not Found" error, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

### 5. Start chatting!
```bash
make chat
```

### What Each Step Does

| Command | What it does | Time |
|---------|--------------|------|
| `make setup` | Installs llama.cpp via Homebrew, Python 3.13 + dependencies via uv | ~2 min |
| `make download` | Downloads Q8_0 GGUF from HuggingFace | ~45 min (varies) |
| `make chat` | Starts interactive chat session | First response: ~30-60 sec |

---

## How It Works

### The Problem

You have 24GB of RAM. The Llama 4 Scout model needs 115 GB (Q8_0 quantized) or 216 GB (BF16 full precision). Traditional loading fails.

### The Solution

**Memory-mapped files (mmap)** - the same technique used by:
- **Apache Arrow** to read larger-than-RAM Parquet files
- **Dask/Spark** to process datasets that don't fit in memory
- **Databases** to work with files larger than available RAM

The OS manages loading and unloading model layers automatically. You get slower but *working* inference.

> **Want to understand the details?** See [docs/CONCEPTS.md](docs/CONCEPTS.md)

---

## Configuration

Edit `config.env` to customize for your system:

```bash
cp config.env.example config.env
nano config.env
```

### Key Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `MODEL_QUANT` | `Q8_0` | Quantization level (Q8_0, Q6_K, Q4_K_M, Q3_K_S, etc.) |
| `RAM_LIMIT` | `12G` | Max RAM for model (set to ~50% of your total RAM) |
| `CONTEXT_SIZE` | `4096` | Conversation memory in tokens (lower = faster) |
| `GPU_LAYERS` | `999` | Layers on Metal GPU (0 for CPU-only) |
| `USE_MMAP` | `true` | **Essential** - memory-maps model for larger-than-RAM operation |
| `USE_MLOCK` | `false` | **Keep false** - allows OS to swap model pages (see below) |
| `DOWNLOAD_TIMEOUT` | `3600` | Download timeout in seconds (60 min default) |
| `DOWNLOAD_MAX_RETRIES` | `5` | Retry attempts for failed downloads |

### Understanding USE_MMAP and USE_MLOCK

These two settings work together to enable larger-than-RAM inference:

| Setting | What it does | For larger-than-RAM |
|---------|--------------|---------------------|
| `USE_MMAP=true` | Memory-maps the model file so the OS loads pages on-demand | **Required** |
| `USE_MLOCK=false` | Allows OS to swap unused model pages out of RAM | **Required** |

If you set `USE_MLOCK=true`, the system tries to lock the entire model in RAM, which will **fail** if the model exceeds your available memory. Keep it `false` for larger-than-RAM operation.

---

## Available Commands

```bash
make help # Show all available commands
```

### Core Commands

| Command | Description |
|---------|-------------|
| `make setup` | Install dependencies (llama.cpp, uv, Python 3.13, `hf` CLI) |
| `make download` | Download the Llama 4 Scout GGUF model |
| `make chat` | Start interactive chat session |
| `make serve` | Start OpenAI-compatible API server |
| `make stop` | Stop the API server |
| `make test` | Run unit tests (requires bats-core) |

---

## API Server Mode

Start an OpenAI-compatible API server:

```bash
make serve
```

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/chat/completions` | POST | Chat completion |
| `/v1/completions` | POST | Text completion |
| `/health` | GET | Health check |

---

## Performance Expectations

| Scenario | Expected Speed |
|----------|----------------|
| Model fits in RAM | ~20-30 tokens/second |
| Model partially in RAM | ~5-15 tokens/second |
| Model mostly on disk | ~1-5 tokens/second |

---

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues and solutions.

---

## Learn More

- [docs/CONCEPTS.md](docs/CONCEPTS.md) - Deep dive into memory mapping, quantization, GGUF
- [llama.cpp](https://github.com/ggerganov/llama.cpp) - The inference engine
- [GGUF Format](https://github.com/ggerganov/ggml/blob/master/docs/gguf.md) - File format specification

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

**Note**: The Llama 4 model has its own license from Meta.

---

*Built for running big models on small machines*
