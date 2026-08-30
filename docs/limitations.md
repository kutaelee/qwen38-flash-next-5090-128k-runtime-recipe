# Limitations

- Hardware sample size is one workstation.
- The GGUF is larger than the WSL memory ceiling, so cold expert-page faults can dominate long prompt processing.
- Baseline decode is currently CPU-expert limited and materially below public best-case RTX 5090 reports.
- Exact long-context retrieval passed, but retrieval support is not equivalent to unreviewed repository-analysis correctness.
- MTP n=4 and canonical n=1 preserved the tested correctness behaviors but were much slower than baseline on this CPU-expert path.
- Canonical MTP n=1 reached 31,775 MiB peak VRAM on a device reporting 32,607 MiB, which is not enough operational margin for a recommended default.
- Ngram benefit and comparison against a separate production model were not measured; ngram was skipped by the predefined MTP prerequisite gate.
- Open experimental readahead/QSA patches were excluded from the pinned build by the fail-closed policy.
