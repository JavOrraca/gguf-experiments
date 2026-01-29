# GGUF Experiments

> **Run Large Language Models that exceed your RAM on macOS**

A CLI framework for running larger-than-RAM LLMs (like Llama 4 Scout) on consumer hardware using memory-mapped inference. Think of it like how Apache Arrow lazily reads larger-than-RAM Parquet files, or how Dask processes datasets that don't fit in memory.

---

## What This Does

This project allows you to run the **Llama 4 Scout 17B-16E** model (or similar large models) on a MacBook with limited RAM by:

1. **Memory-mapping** the model file instead of loading it entirely into RAM
2. **Quantizing** the model to reduce its size (Q4_K_M = ~35GB instead of ~109GB)
3. **Paging** model layers in/out of RAM as needed during inference

**Result**: Slower inference, but it *works* on hardware that couldn't otherwise run the model.

---

## Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **macOS** | 12.0+ | 14.0+ (Sonoma) |
| **Chip** | Apple M1 | Apple M2/M3 |
| **RAM** | 16GB | 24GB+ |
| **Disk** | 60GB free (SSD) | 100GB+ free (NVMe) |

> **Warning:** HDD will be painfully slow. This technique relies on fast disk I/O for paging.

---

## Quick Start

### For the Impatient (5 commands)

# 1. Clone the repository
```bash
git clone https://github.com/JavOrraca/gguf-experiments.git
cd gguf-experiments
```

# 2. Install dependencies (llama.cpp, huggingface-cli)
```bash
make setup
```

# 3. Download the model (~35GB, requires HuggingFace account)
`make download`

# 4. Configure for your system (edit RAM_LIMIT)
```
cp config.env.example config.env
nano config.env  # Set RAM_LIMIT=16G
```

# 5. Start chatting!
`make chat`

### What Each Step Does

| Command | What it does | Time |
|---------|--------------|------|
| `make setup` | Installs llama.cpp via Homebrew, huggingface-cli via pip | ~2 min |
| `make download` | Downloads Q4_K_M GGUF from HuggingFace | ~30 min (varies) |
| `make chat` | Starts interactive chat session | First response: ~30-60 sec |

---

## How It Works

### The Problem

You have 24GB of RAM. The Llama 4 Scout model needs ~35GB (quantized) or ~109GB (full precision). Traditional loading fails.

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
| \`RAM_LIMIT\` | \`16G\` | Max RAM for model (set to ~2/3 of your total RAM) |
| \`CONTEXT_SIZE\` | \`4096\` | Conversation memory in tokens (lower = faster) |
| \`GPU_LAYERS\` | \`999\` | Layers on Metal GPU (0 for CPU-only) |
| \`USE_MMAP\` | \`true\` | **Essential** - enables larger-than-RAM operation |

---

## Available Commands

\`\`\`bash
make help        # Show all available commands
\`\`\`

### Core Commands

| Command | Description |
|---------|-------------|
| \`make setup\` | Install dependencies (llama.cpp, huggingface-cli) |
| \`make download\` | Download the Llama 4 Scout GGUF model |
| \`make chat\` | Start interactive chat session |
| \`make serve\` | Start OpenAI-compatible API server |
| \`make stop\` | Stop the API server |

---

## API Server Mode

Start an OpenAI-compatible API server:

\`\`\`bash
make serve
\`\`\`

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| \`/v1/chat/completions\` | POST | Chat completion |
| \`/v1/completions\` | POST | Text completion |
| \`/health\` | GET | Health check |

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
