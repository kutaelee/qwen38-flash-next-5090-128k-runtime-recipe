#!/usr/bin/env bash
set -euo pipefail

# Experimental only: this exact lane preserved correctness but was rejected for
# throughput and VRAM headroom on the tested MXFP4 + 38 CPU-expert setup.

: "${LLAMA_SERVER:?set LLAMA_SERVER to the tested ik_llama.cpp binary}"
: "${MODEL_PATH:?set MODEL_PATH to the verified NextN GGUF path}"

export GGML_CUDA_NO_PINNED=1

exec "$LLAMA_SERVER" \
  --model "$MODEL_PATH" \
  --ctx-size 131072 \
  --n-gpu-layers 999 \
  --n-cpu-moe 38 \
  --flash-attn on \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --threads 16 \
  --threads-batch 32 \
  --parallel 1 \
  --defer-experts \
  --prefetch-experts \
  --prefetch-experts-threads 8 \
  --spec-type mtp:n_max=1,p_min=0.0 \
  --spec-ckpt-mode gpu-fallback \
  --host 127.0.0.1 \
  --port 18080 \
  --jinja \
  --parallel-tool-calls \
  --metrics
