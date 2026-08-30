# RTX 5090용 Qwen3.8-Flash-Next — 128K WSL2 런타임 레시피

**한국어** | [English](README.md)

> **검증된 baseline 레시피입니다.** RTX 5090 한 장에서 baseline 정확성과 104K-token retrieval을 통과했습니다. MTP는 이 CPU-expert 구성에서 실측 후 비채택했으며, prerequisite gate가 실패해 ngram은 실행하지 않았습니다.

이 저장소는 Qwen3.8-Flash-Next를 OpenAI 호환 loopback 전용 endpoint로 서빙하기 위한 재현 가능한 설정을 제공합니다. 모델 가중치, 비공개 프롬프트, 내부 저장소 정보, 원시 워크스테이션 로그는 포함하지 않습니다.

## 테스트 시스템

| 구성 요소 | 테스트 구성 |
| --- | --- |
| GPU | NVIDIA GeForce RTX 5090, 32,607 MiB reported |
| CPU | 16-core / 32-thread desktop CPU |
| Host RAM | 128 GiB class |
| Runtime | Ubuntu on WSL2, 96 GiB VM memory ceiling |
| Concurrency | 요청 1개, server slot 1개, GPU 1개 |
| Server context | 131,072 tokens |

## 고정한 런타임과 모델

- Runtime: [`ikawrakow/ik_llama.cpp`](https://github.com/ikawrakow/ik_llama.cpp), tested merge commit `d854dfd36a7262fc46cb7542716b04a9f6d4b47d`
- Base commit: `15dddc60b3fc937a9e2a210359ecce392ccdf446`
- MTP patch: [`ik_llama.cpp#2369`](https://github.com/ikawrakow/ik_llama.cpp/pull/2369), head `108dfaa77fdaa138c46b043bfff0e94fbe2adff7`
- Artifact: [`jamesrogers/Qwen3.8-Flash-Next-MTP-MXFP4-GGUF`](https://huggingface.co/jamesrogers/Qwen3.8-Flash-Next-MTP-MXFP4-GGUF)
- Revision: `4a768bf4458a83e1c80667b4d818ec721080546e`
- File: `Qwen3.8-Flash-Next-MXFP4-ngramQ8-NextN.gguf`
- Size: 126,846,153,856 bytes
- SHA-256: `5a4236a6eeda73d23c151f8ed19e5457b0bf1935e1c02c1d42d98a0e26dadde2`

모델은 런타임과 같은 WSL-native Hugging Face cache에 둡니다. 100+ GiB GGUF를 `/mnt/*`를 거쳐 로드하지 마세요.

## Baseline 설정

현재 correctness 기준 설정은 [`configs/ik-llama-baseline-128k.example.sh`](configs/ik-llama-baseline-128k.example.sh)입니다.

- `GGML_CUDA_NO_PINNED=1`을 사용한 mmap 기반 모델 로딩
- `--n-gpu-layers 999`, `--n-cpu-moe 38`, `--defer-experts`
- Flash Attention ON
- Q8_0 K/V cache
- 요청 slot 1개, generation thread 16개, batch thread 32개
- MTP와 ngram OFF
- loopback 전용 OpenAI 호환 endpoint

이 artifact에서는 환경 변수가 중요합니다. 기본 CUDA-host override가 검증 중 98.61 GiB anonymous pinned allocation을 시도했습니다. mmap을 보존하자 이 할당을 피할 수 있었고, 완료된 32K gate의 peak RSS는 약 51.4 GiB였습니다.

테스트한 WSL 상한은 [`configs/wslconfig.example`](configs/wslconfig.example)에 있습니다. 다른 WSL/Docker 작업을 먼저 확인한 뒤 Windows 사용자 프로필의 `.wslconfig`에 적용하세요. 설정 적용에는 전체 WSL 종료가 필요합니다.

## Baseline 실측 결과

| Workload | Prompt | Prompt processing | Decode | 결과 |
| --- | ---: | ---: | ---: | --- |
| 32K needle gate | 26,253 tokens | 271.64 tok/s | 16.53 tok/s | PASS |
| 128K server smoke | 61 tokens | 17.02 tok/s | 15.26 tok/s | PASS |
| 128K long-context needle | 104,805 tokens | 245.72 tok/s | 13.94 tok/s | PASS |

32K 모니터링에서는 startup 25.15초, peak RSS 53,901,956 KiB, 최소 `MemAvailable` 86,701,016 KiB, 최대 swap 사용량 63,708 KiB, peak GPU memory 25,813 MiB가 관측됐습니다. 한 대의 PC에서 얻은 값이며 보편적인 보장값이 아닙니다.

128K server context에서 3회 warm baseline 중앙값은 일반 prose 20.45 tok/s, coding 22.51, editing 20.77, 일반화한 agent/tool workload 18.15, repetition 21.77이었습니다.

MTP n=4는 정확성 8개 항목을 유지했지만 비교 가능한 일반 prose에서 2.52와 3.14 tok/s였습니다. 런타임의 canonical n=1도 정확성은 유지했으나 완료된 short gate에서 0.73–3.58 tok/s였고 peak VRAM은 31,775 MiB였습니다. 따라서 이 artifact/offload 조합에서는 MTP를 권장하지 않습니다. 프로토콜상 유효한 MTP lane이 먼저 필요하므로 ngram은 실행하지 않았습니다. 자세한 내용은 [측정 방법](docs/methodology.md)과 [제한사항](docs/limitations.md)을 참고하세요.

## 재현 순서

1. Upstream 모델 저장소에서 가중치를 직접 받고 revision, byte size, SHA-256을 확인합니다.
2. 고정한 runtime을 CUDA 및 SM120 대상으로 빌드합니다.
3. `LLAMA_SERVER`와 `MODEL_PATH`를 WSL-native 경로로 설정합니다.
4. Baseline 예제를 시작하고 `/health`와 `/v1/models`를 확인합니다.
5. 처리량 측정 전에 basic, deterministic, JSON, single-tool, parallel-tool, tool-continuation 검사를 실행합니다.
6. 32K, 64K, 128K 순서로 검증합니다. 처음부터 최대 context로 시작하지 마세요.
7. 이 artifact에서 MTP는 실험 설정으로 취급합니다. 파라미터를 바꾸기 전에 공개된 비채택 결과를 재현하고, MTP가 정확성과 baseline 이상의 속도를 모두 만족할 때만 ngram을 시험하세요.

전체 절차는 [reproducibility.md](docs/reproducibility.md)에 있습니다.

## 현재 판정

- Memory safety: mmap/no-pinned baseline PASS
- Basic/tool correctness: 8/8 PASS
- 26K retrieval: PASS
- 128K server initialization: PASS
- 104K retrieval: PASS
- Baseline decode: 공개 RTX 5090 reference case보다 느림. CPU expert path가 실측상 주요 병목 후보
- MTP promotion: 이 MXFP4 + 38 CPU-expert path에서 REJECTED
- Ngram promotion: NOT_RUN_BY_GATE

이 저장소는 재현 가능한 서빙 설정입니다. production coding model 교체를 권장하거나 RTX 5090에서 속도가 최적이라고 주장하지 않습니다.

## Upstream 라이선스

이 저장소의 MIT 라이선스는 자체 스크립트와 문서에만 적용됩니다. 모델 가중치와 upstream source는 각각의 라이선스를 따릅니다. 사용 전에 정확한 model card와 runtime license를 확인하세요. 자세한 내용은 [upstream-licenses.md](docs/upstream-licenses.md)에 있습니다.
