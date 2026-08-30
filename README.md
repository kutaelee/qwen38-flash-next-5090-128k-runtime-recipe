# Qwen3.8-Flash-Next on RTX 5090 — 128K WSL2 Runtime Recipe

[한국어](README.ko.md) | **English**

> **Validated baseline recipe.** Baseline correctness and 104K-token retrieval passed on a single RTX 5090. MTP was tested and rejected for this exact CPU-expert configuration; ngram was not run because its prerequisite gate failed.

This repository provides a reproducible setup for serving Qwen3.8-Flash-Next through an OpenAI-compatible, loopback-only endpoint. It contains no model weights, private prompts, or raw workstation logs.

## Tested system

| Component | Tested configuration |
| --- | --- |
| GPU | NVIDIA GeForce RTX 5090, 32,607 MiB reported |
| CPU | 16-core / 32-thread desktop CPU |
| Host RAM | 128 GiB class |
| Runtime | Ubuntu on WSL2, 96 GiB VM memory ceiling |
| Concurrency | One request, one server slot, one GPU |
| Server context | 131,072 tokens |

## Pinned runtime and model

- Runtime: [`ikawrakow/ik_llama.cpp`](https://github.com/ikawrakow/ik_llama.cpp), tested merge commit `d854dfd36a7262fc46cb7542716b04a9f6d4b47d`
- Base commit: `15dddc60b3fc937a9e2a210359ecce392ccdf446`
- MTP patch: [`ik_llama.cpp#2369`](https://github.com/ikawrakow/ik_llama.cpp/pull/2369), head `108dfaa77fdaa138c46b043bfff0e94fbe2adff7`
- Artifact: [`jamesrogers/Qwen3.8-Flash-Next-MTP-MXFP4-GGUF`](https://huggingface.co/jamesrogers/Qwen3.8-Flash-Next-MTP-MXFP4-GGUF)
- Revision: `4a768bf4458a83e1c80667b4d818ec721080546e`
- File: `Qwen3.8-Flash-Next-MXFP4-ngramQ8-NextN.gguf`
- Size: 126,846,153,856 bytes
- SHA-256: `5a4236a6eeda73d23c151f8ed19e5457b0bf1935e1c02c1d42d98a0e26dadde2`

The artifact stays in a runtime-native Hugging Face cache. Do not load a 100+ GiB GGUF across `/mnt/*`.

## Baseline configuration

The current correctness ruler is [`configs/ik-llama-baseline-128k.example.sh`](configs/ik-llama-baseline-128k.example.sh):

- mmap-backed model loading with `GGML_CUDA_NO_PINNED=1`
- `--n-gpu-layers 999`, `--n-cpu-moe 38`, `--defer-experts`
- Flash Attention on
- Q8_0 K/V cache
- one request slot, 16 generation threads, 32 batch threads
- MTP and ngram off
- loopback-only OpenAI-compatible endpoint

The environment switch is important for this artifact: the default CUDA-host override attempted a 98.61 GiB anonymous pinned allocation during validation. Preserving mmap avoided that allocation and kept measured peak RSS near 51.4 GiB in the completed 32K gate.

The tested WSL ceiling is captured in [`configs/wslconfig.example`](configs/wslconfig.example). Copy its contents into the Windows user-profile `.wslconfig` only after inventorying other WSL/Docker work; applying it requires a full WSL shutdown.

## Measured baseline results

| Workload | Prompt | Prompt processing | Decode | Result |
| --- | ---: | ---: | ---: | --- |
| 32K needle gate | 26,253 tokens | 271.64 tok/s | 16.53 tok/s | PASS |
| 128K server smoke | 61 tokens | 17.02 tok/s | 15.26 tok/s | PASS |
| 128K long-context needle | 104,805 tokens | 245.72 tok/s | 13.94 tok/s | PASS |

Completed 32K monitoring observed 25.15 s startup, 53,901,956 KiB peak RSS, 86,701,016 KiB minimum `MemAvailable`, 63,708 KiB maximum swap use, and 25,813 MiB peak GPU memory. Values are one-machine observations, not universal expectations.

Three-run warm baseline medians at 128K server context were 20.45 tok/s for generic prose, 22.51 for coding, 20.77 for editing, 18.15 for a generic agent/tool workload, and 21.77 for repetition.

MTP n=4 preserved the eight correctness checks but completed comparable generic prose samples at 2.52 and 3.14 tok/s. The runtime's canonical n=1 form also preserved correctness but produced 0.73–3.58 tok/s across the completed short gates and reached 31,775 MiB peak VRAM. MTP is therefore not recommended for this artifact/offload split. Ngram was not run because the protocol requires a beneficial MTP lane first. See [methodology](docs/methodology.md) and [limitations](docs/limitations.md).

## Reproduction order

1. Download weights directly from the upstream model repository and verify revision, byte size, and SHA-256.
2. Build the pinned runtime for CUDA and SM120.
3. Set `LLAMA_SERVER` and `MODEL_PATH` to runtime-native WSL paths.
4. Start the baseline example and verify `/health` and `/v1/models`.
5. Run basic, deterministic, JSON, single-tool, parallel-tool, and tool-continuation checks before throughput tests.
6. Validate 32K, 64K, then 128K. Do not jump directly to the maximum context.
7. Treat MTP as an experiment for this artifact. Reproduce the rejection before changing its parameters; test ngram only if MTP becomes both correct and faster than baseline.

Full instructions: [reproducibility.md](docs/reproducibility.md).

## Current disposition

- Memory safety: PASS for mmap/no-pinned baseline
- Basic and tool correctness: PASS (8/8)
- 26K retrieval: PASS
- 128K server initialization: PASS
- 104K retrieval: PASS
- Baseline decode speed: below the public 5090 reference cases; CPU expert path is the leading measured bottleneck candidate
- MTP promotion: REJECTED for this exact MXFP4 + 38 CPU-expert path
- Ngram promotion: NOT_RUN_BY_GATE

This is a reproducible serving recipe, not a recommendation to replace a production coding model or a claim of speed-optimal RTX 5090 inference.

## Upstream licenses

This repository's MIT license applies only to its scripts and documentation. Model weights and upstream source retain their own licenses. Review the exact model card and runtime license before use; see [upstream-licenses.md](docs/upstream-licenses.md).
