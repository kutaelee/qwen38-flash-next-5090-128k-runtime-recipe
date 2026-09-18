# IQ4_XS 32K follow-up on RTX 5090 (2026-09-18)

This note records a bounded follow-up using the newer Unsloth Qwen3.8-Flash-Next `UD-IQ4_XS` GGUF. It does not replace the repository's original MXFP4 baseline.

## Tested lane

- GPU: RTX 5090, 32,607 MiB reported
- Host: 128 GiB class RAM, Ubuntu on WSL2
- Runtime: `ik_llama.cpp` build 4918, commit `dc310244`
- Artifact: Unsloth `Qwen3.8-Flash-Next-UD-IQ4_XS`, 87.238 GiB, three-shard GGUF
- Context: 32,768
- One slot, one request
- PLE: `per_layer_token_embd=CPU`
- Q8_0 K/V cache, Flash Attention on
- mmap + lazy loading
- `GGML_CUDA_NO_PINNED=1`
- speculative decoding off

The sanitized measurements are preserved in [`../benchmarks/iq4xs-32k-followup.csv`](../benchmarks/iq4xs-32k-followup.csv).

## Measured results

The same 23,767-token C++ analysis prompt and 1,000-token output cap were used for both completed runs.

| CPU MoE layers | TTFT | Prefill | Decode | Peak GPU util | Peak VRAM | Peak Windows RAM | Swap delta | Result |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 36 | 292.36 s | not separately preserved | 20.14 tok/s | 76% | 22,797 MiB | 118.14 GB | +251 MiB | PASS, 1,000 tokens |
| 30 | 119.36 s | 199.2 tok/s | 20.99 tok/s | 100% | 30,309 MiB | 120.40 GB | +398 MiB | PASS, 1,000 tokens |

Moving six additional expert layers to the GPU cut TTFT by about 2.45x, but decode improved only from 20.14 to 20.99 tok/s while VRAM and host-memory pressure increased sharply. This makes the tested `ik_llama.cpp` path a poor fit for an always-on speed-oriented runtime on this machine, although it remains functionally usable.

## Operational issues found during setup

Two failures were unrelated to model quality:

1. A local checkout contained Git LFS pointer stubs rather than the actual GGUF shards. Loading those stubs produced an invalid GGUF magic error. The fix was to point the service at the already-downloaded real three-shard model.
2. Launching the server from a short-lived `wsl.exe` session allowed the server to die with the parent session. Running it as a WSL systemd service fixed process lifetime and restart behavior.

Neither issue explains the remaining throughput gap once the server is healthy.

## Why this is slower than the public 32 GiB reference

The public [`lukaLLM/Qwen3.8-Flash-Next-VRAM-Benchmark`](https://github.com/lukaLLM/Qwen3.8-Flash-Next-VRAM-Benchmark) result is not the same runtime path.

Its published 32 GiB lane uses upstream `llama.cpp` build `b10666` / commit `4e97ac86e`, `--n-cpu-moe 36`, mmap loading, and the same IQ4_XS family. Reported decode falls with context: 42.24 tok/s at 2K, 39.57 at 8K, and 33.21 at 32K. Therefore 42.2 tok/s is not a valid direct target for a 23.7K prompt.

Even after accounting for prompt length, this follow-up's ~20 tok/s remains materially lower than the public 32K figure. The leading differences are:

- upstream `llama.cpp` vs this run's `ik_llama.cpp`
- this run disables CUDA pinned host allocation after a very large host registration attempt failed
- `--defer-experts` and the associated host path differ from the public upstream lane
- WSL2 and host-memory behavior differ from the reference host
- the public "32 GiB" lane was measured on an RTX PRO 6000 Blackwell with VRAM software-limited to 32 GiB; it reproduces capacity, not every property of a physical RTX 5090

The data do not support calling ~21 tok/s an absolute RTX 5090 limit.

## If this is revisited

Do not download another copy of the 87.2 GiB model. Reuse the verified IQ4_XS shards and change only the runtime:

1. Keep the current `ik_llama.cpp` installation intact.
2. Build a separate upstream `llama.cpp` checkout pinned to the public reference revision (`b10666` / `4e97ac86e`).
3. Reproduce the published 32 GiB placement with `--n-cpu-moe 36`, PLE on CPU, mmap loading, one slot, and no speculative decoding.
4. Serve it on a separate loopback port and run the same 23.7K prompt once.
5. If decode rises toward the published 30+ tok/s range, the runtime/host-transfer path was the main difference. If it remains near 20 tok/s, investigate WSL2 and host DDR5 bandwidth before changing quantization or model weights.

Until there is a quality result that justifies the resource cost, keep the faster 27B runtime as the default and treat Flash-Next as an on-demand specialist rather than an always-resident service.
