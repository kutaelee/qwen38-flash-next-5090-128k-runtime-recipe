# Reproduction guide

## 1. Prerequisites

- One CUDA-capable 32 GiB GPU
- 128 GiB class host RAM
- WSL2 with enough memory headroom for the selected CPU-expert policy
- CUDA toolkit capable of building SM120 kernels
- `git`, CMake, Ninja, GCC/G++, Python 3, and `curl`

Keep Linux source, build output, and the GGUF on the WSL ext4 filesystem. Do not load the model through `/mnt/*`.

## 2. Pin the runtime

Clone `ikawrakow/ik_llama.cpp`, fetch the exact tested base and PR head, and create a local merge commit equivalent to the pinned tested commit documented in the README. Verify `git rev-parse HEAD` before building.

Example build shape; recheck the pinned source's CMake options before use:

```bash
cmake -S . -B build-release -G Ninja \
  -DGGML_CUDA=ON \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build-release -j
```

Confirm that `llama-server`, `llama-cli`, and `llama-bench` exist and that the CUDA backend recognizes the RTX 5090.

## 3. Verify the artifact

Download directly from the upstream Hugging Face repository at the immutable revision shown in the README. Verify:

```bash
stat -Lc '%s' "$MODEL_PATH"
sha256sum "$MODEL_PATH"
```

Both byte size and digest must match before launch. The file must contain the integrated NextN tensors before the MTP lane is attempted.

## 4. WSL memory

The tested WSL2 memory ceiling was 96 GiB; see `configs/wslconfig.example`. Apply `.wslconfig` changes only after considering other WSL/Docker workloads. A full `wsl --shutdown` is required and will interrupt every running distro, so schedule it rather than using it while unrelated work is active. Verify `MemTotal`, `MemAvailable`, and swap inside the distro before loading the model.

## 5. Baseline first

Set environment variables and launch:

```bash
export LLAMA_SERVER=/path/to/build/bin/llama-server
export MODEL_PATH=/path/to/Qwen3.8-Flash-Next-MXFP4-ngramQ8-NextN.gguf
bash configs/ik-llama-baseline-128k.example.sh
```

Run the health check from PowerShell:

```powershell
pwsh -NoProfile -File .\scripts\healthcheck.example.ps1
```

Do not send inference until `/health` reports `ok`.

## 6. Validation order

1. Basic facts, Korean, code, JSON
2. Deterministic repeat
3. Single and parallel tool calls
4. Tool result continuation
5. 8K, 32K, 64K, then 128K needle retrieval
6. Cold and warm prompt/decode benchmark, at least three repeats
7. MTP with identical prompt/seed/sampling
8. MTP rejection/recovery and recurrent-state correctness
9. ngram only for edit/repetition workloads

Record raw per-run results. Never publish only an average.
