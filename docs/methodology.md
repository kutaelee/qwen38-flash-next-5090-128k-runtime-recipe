# Methodology

- One server slot and one request are used for every published row.
- Cold and warm behavior are reported separately.
- Prompt processing and decode throughput come from server timing fields, not client-side estimates.
- Peak RSS, `MemAvailable`, swap, model read bytes, VRAM, GPU utilization, and PCIe telemetry are sampled while the server runs.
- Correctness gates precede throughput: basic facts, Korean output, code, JSON, deterministic replay, single/parallel tools, and tool-result continuation.
- Context tests use an exact needle embedded in synthetic filler and record the actual token count returned by the server.
- MTP must use the same model artifact, prompt, seed, and sampling parameters as baseline.
- A clearly dominated long-running lane may be stopped after completed comparable samples already decide the release gate; interrupted requests are never reported as completed TPS values.
- Ngram is tested only after MTP passes correctness, performance, and operational-headroom gates.
- Missing results remain `NOT_MEASURED`; no interpolation is allowed.
