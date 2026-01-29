# Troubleshooting Guide

This guide covers common issues you might encounter when running larger-than-RAM LLMs and how to resolve them.

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [Download Issues](#download-issues)
3. [Memory Issues](#memory-issues)
4. [Performance Issues](#performance-issues)
5. [Server Issues](#server-issues)
6. [Model Issues](#model-issues)
7. [Apple Silicon Specific](#apple-silicon-specific)

---

## Installation Issues

### "brew: command not found"

**Problem**: Homebrew is not installed or not in your PATH.

**Solution**:
```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# For Apple Silicon, add to PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc
```

### "llama-cli: command not found" after setup

**Problem**: llama.cpp installed but not in PATH.

**Solution**:
```bash
# Check if it's installed
brew list llama.cpp

# If installed, add Homebrew to PATH
export PATH="/opt/homebrew/bin:$PATH"

# Make permanent
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### pip/Python errors during setup

**Problem**: Python environment issues.

**Solution**:
```bash
# Install Python via Homebrew
brew install python@3.11

# Use explicit Python path
/opt/homebrew/bin/python3 -m pip install huggingface_hub

# Or create a virtual environment
python3 -m venv ~/.venv/gguf
source ~/.venv/gguf/bin/activate
pip install huggingface_hub
```

---

## Download Issues

### "401 Unauthorized" or "Access denied"

**Problem**: Not logged in to HuggingFace or haven't accepted the model license.

**Solution**:
```bash
# 1. Create account at https://huggingface.co
# 2. Accept license at https://huggingface.co/meta-llama/Llama-4-Scout-17B-16E-Instruct
# 3. Create token at https://huggingface.co/settings/tokens
# 4. Login
huggingface-cli login
```

### "Repository not found" or "Entry not found" (404 Error)

**Problem**: The configured HuggingFace GGUF repository doesn't exist, or the quantization/file doesn't exist. This is common with newer models like Llama 4 Scout where community GGUF quantizations may use different naming conventions.

**Error examples**:
```
huggingface_hub.errors.RepositoryNotFoundError: 404 Client Error.
Repository Not Found for url: https://huggingface.co/...
```
```
huggingface_hub.errors.EntryNotFoundError: 404 Client Error.
Entry Not Found for url: https://huggingface.co/.../Llama-4-Scout-17B-16E-Instruct-Q8_0.gguf
```

**Solution**:

1. **Find a valid GGUF repository** on HuggingFace:
   - Search: https://huggingface.co/models?search=llama-4-scout+gguf
   - Or browse popular quantizers:
     - [unsloth](https://huggingface.co/unsloth) - Often first with new model quantizations
     - [lmstudio-community](https://huggingface.co/lmstudio-community) - LM Studio's official GGUF repo
     - [bartowski](https://huggingface.co/bartowski) - Prolific GGUF quantizer
     - [TheBloke](https://huggingface.co/TheBloke) - Large collection of quantizations

2. **Check available quantizations** in the repository:
   - Visit: `https://huggingface.co/<HF_REPO>/tree/main`
   - **Folders** (like `Q8_0/`, `Q4_K_M/`) contain **sharded models** (split into multiple files)
   - **Single .gguf files** at root are smaller quantizations in one file

3. **Update your `config.env` file**:
```bash
# Open config.env in your editor
nano ./config.env

# Update these settings:
HF_REPO=unsloth/Llama-4-Scout-17B-16E-Instruct-GGUF   # Repository name
MODEL_QUANT=Q8_0                                       # Quantization level (folder or file prefix)
MODEL_NAME=Llama-4-Scout-17B-16E-Instruct             # Model name prefix
```

4. **Re-run the download**:
```bash
make download
```

**Tip**: Check `config.env.example` for detailed instructions on finding and configuring GGUF repositories.

**Official Model Reference**: The official Llama 4 Scout model (safetensors format, not GGUF) is at:
https://huggingface.co/meta-llama/Llama-4-Scout-17B-16E-Instruct

### Understanding Sharded vs Single-File Models

**Sharded models** are large quantizations split across multiple files for easier downloading:
```
Q8_0/
  Llama-4-Scout-17B-16E-Instruct-Q8_0-00001-of-00003.gguf
  Llama-4-Scout-17B-16E-Instruct-Q8_0-00002-of-00003.gguf
  Llama-4-Scout-17B-16E-Instruct-Q8_0-00003-of-00003.gguf
```

**Single-file models** are smaller quantizations in one file:
```
Llama-4-Scout-17B-16E-Instruct-Q3_K_S.gguf
Llama-4-Scout-17B-16E-Instruct-Q2_K.gguf
```

The download script automatically detects which type you're downloading based on `MODEL_QUANT`:
- **Sharded**: `Q8_0`, `Q6_K`, `Q5_K_M`, `Q4_K_M`, `BF16`, etc.
- **Single-file**: `Q3_K_S`, `Q2_K`, `Q2_K_L`, etc.

For sharded models, llama.cpp only needs the path to the **first shard** (`-00001-of-XXXXX.gguf`), and it will automatically load all parts.

### Download stuck or very slow

**Problem**: Large file download issues.

**Solution**:
```bash
# Use resume-capable download
huggingface-cli download bartowski/Llama-4-Scout-17B-16E-Instruct-GGUF \
  Llama-4-Scout-17B-16E-Instruct-Q4_K_M.gguf \
  --local-dir ./models \
  --resume-download

# Or try wget with resume
wget -c "https://huggingface.co/<repo>/resolve/main/<file>.gguf"
```

### "Not enough disk space"

**Problem**: Insufficient storage for the model.

**Solution**:
```bash
# Check available space
df -h .

# You need at least 50GB free for Q4_K_M
# Options:
# 1. Free up disk space
# 2. Use smaller quantization (Q3_K_S instead of Q4_K_M)
# 3. Download to external drive and symlink
ln -s /Volumes/ExternalDrive/models ./models
```

---

## Memory Issues

### "mmap failed" or "Cannot allocate memory"

**Problem**: System cannot create memory mapping.

**Solution**:
```bash
# Check available memory
vm_stat | head -10

# Close memory-intensive applications
# Restart your Mac to free up memory

# Reduce context size in config.env
CONTEXT_SIZE=2048  # Instead of 4096
```

### System becomes unresponsive during inference

**Problem**: Too much memory pressure causing swap thrashing.

**Solution**:
1. **Reduce RAM usage** in `config.env`:
```bash
RAM_LIMIT=12G  # Use less RAM
CONTEXT_SIZE=2048
BATCH_SIZE=256
```

2. **Monitor memory** in another terminal:
```bash
# Watch memory usage
while true; do vm_stat | grep "Pages free"; sleep 2; done
```

3. **Use Activity Monitor**: Check "Memory Pressure" graph

### "Killed" or process terminates unexpectedly

**Problem**: macOS killed the process due to memory pressure.

**Solution**:
```bash
# Check if OOM killed the process
log show --predicate 'eventMessage contains "Killed"' --last 5m

# Reduce memory usage
GPU_LAYERS=0  # Disable Metal to reduce memory
CONTEXT_SIZE=1024
USE_MLOCK=false  # Don't lock memory
```

---

## Performance Issues

### Very slow inference (< 1 token/second)

**Causes and Solutions**:

1. **Model larger than RAM** (expected behavior):
```bash
# This is normal for larger-than-RAM inference
# Speed depends on SSD performance

# Check if using mmap
grep USE_MMAP config.env  # Should be true
```

2. **Using HDD instead of SSD**:
```bash
# Check disk type
diskutil info / | grep "Solid State"
# MUST be Yes for reasonable performance
```

3. **Too many GPU layers without enough VRAM**:
```bash
# In config.env, try:
GPU_LAYERS=0  # Force CPU-only
```

### First response takes very long (> 2 minutes)

**Problem**: Initial model loading is slow.

**Solution**:
```bash
# This is normal for cold start
# First inference loads model pages into RAM

# To speed up:
# 1. Use smaller context
CONTEXT_SIZE=2048

# 2. Keep the model running (use server mode)
make serve
# Server stays warm between requests
```

### Chat gets slower over time

**Problem**: KV cache growing with conversation length.

**Solution**:
```bash
# Clear conversation by restarting chat
# Ctrl+C then 'make chat' again

# Or reduce context size
CONTEXT_SIZE=2048  # Limits conversation history
```

---

## Server Issues

### "Port 8080 is already in use"

**Problem**: Another process is using the port.

**Solution**:
```bash
# Find what's using port 8080
lsof -i :8080

# Kill the process
kill $(lsof -t -i:8080)

# Or use a different port
make serve PORT=9000

# In scripts/serve.sh:
./scripts/serve.sh --port 9000
```

### "Connection refused" when calling API

**Problem**: Server not running or wrong address.

**Solution**:
```bash
# Check if server is running
pgrep -f llama-server

# Check what port it's on
lsof -i -P | grep llama

# Test health endpoint
curl http://127.0.0.1:8080/health
```

### API calls timeout

**Problem**: Inference taking too long.

**Solution**:
```bash
# Increase client timeout
curl --max-time 300 http://localhost:8080/v1/chat/completions ...

# In Python:
import requests
response = requests.post(url, json=data, timeout=300)

# Or reduce max_tokens in request
{"max_tokens": 100}  # Instead of 2048
```

---

## Model Issues

### "Invalid GGUF file" or "Failed to load model"

**Problem**: Corrupted or incomplete download.

**Solution**:
```bash
# Check file size matches expected
ls -lh ./models/*.gguf

# Re-download
rm ./models/*.gguf
make download
```

### "Unknown model architecture"

**Problem**: llama.cpp version doesn't support this model.

**Solution**:
```bash
# Update llama.cpp
brew upgrade llama.cpp

# Check version
llama-cli --version
```

### Gibberish or nonsensical output

**Problem**: Wrong chat template or corrupted model.

**Solution**:
```bash
# Check if using correct chat template
# In serve.sh, ensure:
--chat-template llama3

# Or let llama.cpp auto-detect
# Remove --chat-template flag

# If still broken, try different quantization
# Download Q5_K_M instead of Q4_K_M
```

---

## Apple Silicon Specific

### Metal not being used

**Problem**: GPU acceleration not working.

**Solution**:
```bash
# Check Metal support
system_profiler SPDisplaysDataType | grep Metal

# Ensure GPU_LAYERS is set
GPU_LAYERS=999  # In config.env

# Check llama.cpp Metal support
llama-cli --help | grep -i metal
```

### "Metal: error" in output

**Problem**: Metal shader compilation or memory issues.

**Solution**:
```bash
# Try CPU-only mode
GPU_LAYERS=0

# Or reduce GPU layers
GPU_LAYERS=20  # Partial offload

# Update macOS if possible (Metal improves with updates)
```

### High CPU usage even with Metal

**Problem**: Some operations still run on CPU.

**Explanation**: This is normal! Metal accelerates matrix multiplications, but:
- Tokenization runs on CPU
- Some layers may not fit in GPU memory
- CPU handles memory mapping

---

## Getting Help

### Collect Debug Information

When asking for help, include:

```bash
# System info
make info

# Model info
ls -lh ./models/
file ./models/*.gguf

# Config
cat config.env

# Error messages
# (copy the full error output)
```

### Where to Get Help

1. **This repository**: Open a GitHub issue
2. **llama.cpp issues**: https://github.com/ggerganov/llama.cpp/issues
3. **HuggingFace forums**: https://discuss.huggingface.co/

### Reporting Issues

When reporting issues:
1. Include your macOS version (`sw_vers`)
2. Include your chip (`sysctl -n machdep.cpu.brand_string`)
3. Include RAM size (`sysctl -n hw.memsize`)
4. Include llama.cpp version (`llama-cli --version`)
5. Include the full error message
6. Describe what you expected vs. what happened
