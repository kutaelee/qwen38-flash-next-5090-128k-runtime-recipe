#!/usr/bin/env bash
set -euo pipefail

: "${LLAMA_SERVER:?set LLAMA_SERVER to the WSL-native llama-server binary}"
: "${MODEL_PATH:?set MODEL_PATH to the verified WSL-native GGUF path}"

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
  --host 127.0.0.1 \
  --port 18080 \
  --jinja \
  --parallel-tool-calls \
  --metrics

